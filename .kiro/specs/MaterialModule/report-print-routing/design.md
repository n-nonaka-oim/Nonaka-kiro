# 設計書

## はじめに

MaterialModule の帳票出力を3方式（**PDFプリント**／**PDFエージェント**／**SMTPエージェント**）に整理し、ページ・ユーザー印刷設定（帳票別）・システム印刷設定（外部出力）に応じて出し分ける。サーバ登録プリンタ一覧は CommonModule `IPrinterQueryService`（別 spec `printer-list-query`）から取得。PDF保管は固定パス（`m_print_output_path`）。clnCoCore 非改変・CommonModule はインターフェース経由。

## アーキテクチャ

```
[Orders/Create 承認(Approvals)]         [Dispatches 「請求」]        [Receivings 「入庫伝票」]
        │ 出力区分                             │                            │
        ▼                                      ▼                            ▼
  1=印刷→PDFエージェント                (i) PDFプリント(HTTP)        PDFプリント(HTTP)
  2=FAX →SMTPエージェント               (ii) PDFエージェント
  3=両方(同時)                               （外部出力ON時）
        │                                      │
        ├─ PDFエージェント: printer_name = ユーザー印刷設定(user×report_type) を解決
        │        └→ IPrintQueueService.EnqueueAsync(printer_name 指定) → t_print_queue → PrintAgent サイレント
        ├─ SMTPエージェント: 既存 DispatchEnqueueService → t_smtp_queue
        └─ PDFプリント: MainWeb が生成PDFを HTTP 配信 → ブラウザ既定プリンタ(ダイアログ)

[ユーザー印刷設定 画面(自己サービス)] --選択元--> CommonModule.IPrinterQueryService.GetAvailablePrintersAsync
```

### 方式と解決の要点
- **PDFプリント**：Razor Page ハンドラが `File(bytes, "application/pdf")` でPDFを返す。ブラウザで開く/印刷（ダイアログ）。サーバ登録プリンタ非依存。
- **PDFエージェント**：`IPrintOutputResolver`（新規）が対象ユーザー×帳票種別から printer_name を解決 → `IApprovalReportPdfProvider`/PDF生成で保存 → `IPrintQueueService.EnqueueAsync(printerName 指定)`。未割当は投入せずクライアントエラー。
- **SMTPエージェント**：既存 `DispatchEnqueueService` を踏襲。

## データモデル

### m_user_print_setting（新規・MaterialModule / db_material_dev）

| 列 | 型 | 備考 |
|---|---|---|
| id | int | PK, Identity |
| user_code | nvarchar(40) | ログイン名（`t_orders.user_id` 相当） |
| report_type | nvarchar(40) | 帳票種別（order_approval / dispatch_request / receiving） |
| printer_name | nvarchar(200) | サーバ登録プリンタ名（`m_printer.printer_name`） |
| created_at / updated_at | datetime | 監査 |
| row_version | rowversion | 楽観ロック |

- 一意制約：`(user_code, report_type)`。

### m_print_system_setting（新規・MaterialModule / db_material_dev）

| 列 | 型 | 備考 |
|---|---|---|
| id | int | PK, Identity |
| report_type | nvarchar(40) | 帳票種別（当面 dispatch_request） |
| external_output_enabled | bit | 外部出力フラグ（(ii)出力ON/OFF） |
| printer_name | nvarchar(200) | (ii) 出力プリンタ（サーバ登録） |
| created_at / updated_at | datetime | 監査 |
| row_version | rowversion | 楽観ロック |

- 一意制約：`(report_type)`。

### エンティティ / DbSet
- `Data/Entities/MUserPrintSetting.cs`・`Data/Entities/MPrintSystemSetting.cs` を追加。`MaterialDbContext` に `DbSet` と一意インデックスを追加。

## コンポーネント設計

### IPrintOutputResolver / PrintOutputResolver（新規・MaterialModule）
```csharp
public interface IPrintOutputResolver
{
    // ユーザー×帳票種別の PDFエージェント割当プリンタ（未割当は null）
    Task<string?> ResolveUserPrinterAsync(string userCode, string reportType, CancellationToken ct = default);
    // Dispatches(ii) システム設定（外部出力ON/OFF＋プリンタ）
    Task<PrintSystemSetting?> ResolveSystemSettingAsync(string reportType, CancellationToken ct = default);
    // テストSMTP宛先（自分宛）：ApplicationUser.Email → GeneralPersonalInfo(email, DEFAULT含む)
    Task<string?> ResolveSelfEmailAsync(string loginName, CancellationToken ct = default);
}
```
- `ResolveUserPrinterAsync`：`m_user_print_setting` を (user_code, report_type) で検索。
- `ResolveSelfEmailAsync`：`UserManager.FindByNameAsync` → Email、空なら `IMasterService.GetGeneralPersonalInfoAsync`→email（既存 `ISenderInfoResolver.ResolveSenderEmailAsync` を再利用可）。

### PDFプリント（各ページ）
- Orders/Create・Dispatches・Receivings に「PDFプリント」導線（ハンドラ）を用意し、生成PDFを `File(bytes, "application/pdf", fileName)` で返す（ダウンロード/インライン表示→ダイアログ印刷）。

### PDFエージェント投入
- 既存 `PrintJobService.CreateOrderApprovalJobsAsync` は `printerName: null`（サーバ既定）で投入していた箇所を、**解決した printer_name**を渡すよう変更。
  - Orders/Create（承認時）：発注者(user_id)×`order_approval` の割当を解決。未割当なら当該ジョブはクライアントエラー（承認フローでの扱いは下記「エラー処理」）。
  - Dispatches(ii)：`m_print_system_setting`（dispatch_request）の printer_name。外部出力OFFなら投入しない。

### SMTPエージェント
- 既存 `DispatchEnqueueService.EnqueueOrderApprovalFaxAsync` を踏襲（出力区分2/3 で FAX 投入）。

### テスト出力（エージェント時のみ）
- エージェント使用ページ（Orders/Create・Dispatches(ii)）に「テスト出力」チェックボックス。
- ON：本番フロー（承認・請求）を経由せず、`IPrintQueueService`/`ISmtpQueueService` へ即時投入。
  - PDFエージェント：実行ユーザーの割当プリンタ（未割当はクライアントエラー）。
  - SMTPエージェント：`ResolveSelfEmailAsync` の自分宛。件名/本文にテスト明示。

### ユーザー印刷設定 画面（自己サービス）
- `Areas/Material/Pages/PrintSettings/Index`（新規）。ログインユーザーの `m_user_print_setting` を帳票種別ごとに表示・編集。プリンタ選択肢＝`IPrinterQueryService.GetAvailablePrintersAsync`。`row_version` で楽観ロック。`[Authorize(Policy = "DbPermissionCheck")]`（アクセス可否は認可側）。

## エラー処理

- **PDFエージェント割当未設定**：
  - テスト出力・手動導線：投入前バリデーションで**クライアントにエラー**表示（サーバ既定へFBしない）。
  - Orders/Create 承認時：承認自体は成立させつつ、印刷投入不可を**画面に警告表示**（承認をブロックしない／ログ記録）。※承認ブロックの要否は実装時に最終確認。
- **PrintAgent 未到達/未インストール**：現行 PrintAgent は printer_name 指定で未インストール時 status=9（エラー）。本改修は投入前に割当有無を検証（到達性の最終判定はエージェント側）。
- CommonModule 一覧取得失敗：画面はエラー表示（設定不可）。

## 正しさのプロパティ（PBT 対象）

- **P1（方式判定）**：出力区分→方式の対応が全域で一致（0=なし/1=PDFエージェント/2=SMTPエージェント/3=両方）。純粋関数 `ResolveOutputKinds(outputType)`。
- **P2（外部出力ゲート）**：Dispatches(ii) 投入は `external_output_enabled == true` かつ printer_name 非空 と同値。
- **P3（テストSMTP宛先）**：`ResolveSelfEmail` は Email→master(DEFAULT含む) の順で最初の非空、無ければ null。
- **P4（割当解決）**：ResolveUserPrinter は (user, report_type) 一致行の printer_name、無ければ null（フォールバックしない）。

## テスト戦略
- `MaterialModule.Tests` に純粋ロジック（`ResolveOutputKinds`・外部出力ゲート判定・自分宛メール解決）のプロパティ/単体テスト。
- I/O（Resolver/投入/画面）は結合最小・純粋ロジックに寄せる。
- ビルド/テスト/DB適用はユーザー。

## DB / スキーマ SQL（ユーザー適用）
- `MaterialModule/docs/sql/create_m_user_print_setting.sql`・`create_m_print_system_setting.sql`（作成＋一意インデックス）。
