---
inclusion: fileMatch
fileMatchPattern: "**/MaterialModule/**"
---

# MaterialModule 開発ルール

## プロジェクト情報

- プロジェクトパス: `\\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\MaterialModule`
- SDK: Microsoft.NET.Sdk.Razor / net8.0
- DB: db_material_dev（SQL Server, OJIADM23120073\DEVELOPMENT, SA認証）
- 接続文字列キー: "MaterialDb"
- テスト: xUnit + FsCheck.Xunit
- NuGet: QuestPDF, ClosedXML, QRCoder

## 変更対象スコープ

- **MaterialModule配下のみ変更対象**。clnCoCore（MainWeb, AuthModule, SharedCore等）は変更しない
- m_purchase_conditions は読み取り専用（変更禁止）

## セッション引継ぎ

- 作業開始時: `.kiro/session-memo/` 配下の最新 session-memo-*.md を読むこと
- 作業終了時: session-memo を更新し、完了作業・次回予定・参照ファイルを記録すること

## DB設計ルール

- DB設計の提案は先に行い、ユーザーの承認を得てから実装すること
- テーブル命名: m_（マスタ）、t_（トランザクション）、r_（中間）
- カラム命名: snake_case、英語表記
- 必須カラム: id, created_at, updated_at
- t_orders は結果テーブル（FK制約なし）

## ステータスフロー（確定）

| order_status_id | 表示名（m_order_statuses） | タイミング |
|---|---|---|
| 10 | エントリ | 新規入力 |
| 15 | 差戻し | 差戻し（order_noリセット） |
| 20 | 承認待ち | 登録ボタン（order_noは空） |
| 30 | 回答待ち | 承認ボタン（**発注番号採番**） |
| 50 | 注文確定 | 納期回答確認（Confirm画面） |
| 60 | 入庫済み | 倉庫入れ（Receivings画面） |

※ ステータス40（未承認）は廃止（is_active=0）

## 発注番号採番

- フォーマット: `プラントコード-yyMMdd-グループ番号3桁-連番3桁`（例: G201-260515-001-001）
- 採番タイミング: **Approvals「承認」時**（ステータス20→30）
- グループ条件: 送付先コード + 品目コード + 発注者 + 出力区分
- 枝番上限: 最大20件、21件以上でグループ番号カウントアップ
- 排他制御: UPDLOCK + HOLDLOCK

## アーキテクチャパターン

- public interface + internal 実装クラス（DemoModuleパターン）
- DI登録: `MaterialModuleExtensions.AddMaterialModule()`
- 全ページ: `[Authorize(Policy = "DbPermissionCheck")]`
- 全I/O: async/await
- 楽観的ロック（OrderStatusHelper）を全ステータス変更に適用
- ユーザー情報: SharedCore（IUserRepository）経由で取得
- 出庫は t_orders と切り離し（在庫ベース）
- **OrderListDto変換は `Extensions/OrderQueryExtensions.ToOrderListDto()` を使用**（Select句の集約）
- 時刻: JST（Tokyo Standard Time）を使用

## ビルド・実行ルール

- ビルドはユーザーの指示があった時のみ実行
- PowerShellでのファイル書き込みは禁止（ファイル破損リスク）→ str_replace / fs_write のみ使用

## プロジェクト構造

```
MaterialModule/
├── Areas/Material/Pages/
│   ├── _ViewImports.cshtml, _ViewStart.cshtml
│   ├── Orders/          (Create, Confirm, Search)
│   ├── Approvals/       (Index)
│   ├── JobQueue/        (Index)
│   ├── Receivings/      (Index)
│   ├── Dispatches/      (Index)
│   ├── DeliveryMonitor/ (Index)
│   ├── Forecasts/       (Index)
│   ├── Mrp/             (Index)
│   └── PrintQueue/
├── Data/
│   └── Entities/        (TOrder, TReceiving, TDispatch, TStock, etc.)
├── Extensions/
│   └── OrderQueryExtensions.cs  ← Select句集約
├── Models/
│   └── Dtos/            (OrderListDto, OrderCreateDto, etc.)
├── Services/
│   ├── I*.cs            (public interfaces)
│   ├── *Service.cs      (internal implementations)
│   ├── OrderStatusHelper.cs
│   └── OrderPdfService.cs
├── Doc/
│   ├── order-status-flow.md
│   └── *.md (資材固有の設計書)
└── MaterialModule.csproj
```

## ページ仕様（現在）

### Orders/Create
- 品目サジェスト検索、エントリ→登録（order_noは空のまま）
- デフォルトソート: 起票日降順
- ページサイズ切り替え: 10/20/30/50件

### Approvals
- 未承認リスト: チェックボックス + 承認/差戻しボタン（リスト外のみ、行内ボタンなし）
- 承認済リスト: 発注番号列あり（ソート可）
- 差戻しリスト: 発注番号列なし
- 承認時: 発注番号採番 + t_order_reports作成
- ソート: 合計数量、起票日、納期、発注番号、品目名、単価、金額、送付先

### JobQueue（ジョブリスト）
- グループ単位表示（発注番号グループ）
- PDF: ダウンロード方式（fetch + Blob）
- 表示条件: print_status=フィルタ値

### Orders/Confirm（納期回答確認）
- 全ユーザー表示 + 発注者ドロップダウン
- 編集: 個数（整数）/入目/納期
- ソート: 発注番号、品目コード、品目名、個数、発注日、納期、送付先

### Receivings（入庫リスト）
- ステータス50+60の統合表示
- 状態列（未入庫/入庫済バッジ）
- フィルタ: 状態、納期From/To、入庫日From/To、倉庫
- 編集（未入庫のみ）: 個数（整数）、ロットNo、入庫日、備考
- 個数変更時: 備考にFromTo自動追記
- 入庫伝票PDF: ダウンロード方式

### 発注書兼納入依頼書PDF
- グループ単位1ページ（最大20件明細）
- QRコード: 発注番号左側（35×35pt）
- 承認印: 2段テキスト（名前+日付）、枠内に内枠
- 左余白: 40mm、明細9pt

## 参照ドキュメント

- セッションメモ: `.kiro/session-memo/session-memo-*.md`
- ステータスフロー: `MaterialModule/docs/order-status-flow.md`
- 設計書: `MaterialModule/docs/*.md`
