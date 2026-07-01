# Implementation Plan: order-approval-fax-mail（発注承認時の発注書 FAX送信）

## Overview

design.md に基づき、発注承認（個別 `ApproveOrderAsync` / 一括 `ApproveOrdersAsync`）を契機に発注書PDFを生成・共有フォルダへ保管し、共通SMTP送信基盤の投入ヘルパー `ISmtpQueueService.EnqueueAsync` を通じて共通送信キュー `t_smtp_queue`(`db_common_dev`) へFAX送信ジョブを投入する機能を段階的に実装する。

実装は「CommonModule 参照・設定基盤 → 送信履歴エンティティ/DbContext/DDL → 送信投入サービスの純粋ロジック → サービス本体アルゴリズム → DI登録・承認統合 → チェックポイント → Spec同期」の順で進め、各段階で検証できるようにする。

実装の中心は新規サービス `IDispatchEnqueueService` / `DispatchEnqueueService` と、二重送信防止用の新規エンティティ `TOrderDispatchLog`（`t_order_dispatch_log`）である。本機能は **FAXのみ** を対象とし、既存の印刷経路(`PrintJobService`→`t_order_reports`→PrintAgent)は変更せず並行維持する（FAXは常に `t_smtp_queue` 経由に一本化）。

前提・運用ルール:
- **ビルド・DBスキーマ適用(DDL)・実FAX送信・テスト実行はユーザー側で実施する**。タスクではコード/DDLファイルの作成・更新までを行い、ビルド・DDL実行・実送信・テスト実行は行わない（project-rules.md準拠）。
- Correctness Property（Property 1〜11）は FsCheck（既存 `MaterialModule.Tests` に準拠）で**最低100イテレーション**実装し、各テストに `// Feature: order-approval-fax-mail, Property {n}` タグを付す。
- 新規エンティティ `TOrderDispatchLog` には `row_version`(`[Timestamp]`) を付与し、`(reference_code, dispatch_type)` の複合一意制約で二重投入を防ぐ。
- DBスキーマ変更に伴い `MaterialModule/Doc/テーブル定義書.md` と `MaterialModule/Doc/ER図.md` を更新する。
- Spec は正本 `.kiro/specs/order-approval-fax-mail/` とコピー `MaterialModule/Doc/specs/order-approval-fax-mail/` の2箇所に配置する。

## Tasks

- [x] 1. CommonModule への参照追加と設定基盤
  - [x] 1.1 MaterialModule.csproj に CommonModule への ProjectReference を追加
    - `MaterialModule/MaterialModule.csproj` に `<ProjectReference Include="..\CommonModule\CommonModule.csproj" />` を追加
    - 投入ヘルパー `ISmtpQueueService` を MaterialModule から参照可能にする（`t_smtp_queue` への直接読み書きは行わず `ISmtpQueueService` 経由のみ）
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.2 FaxDispatchOptions（設定はモジュール既定で完結・MainWeb不変更）
    - `MaterialModule/Configuration/FaxDispatchOptions.cs` を新規作成（`TestSendEnabled`/`TestFaxNumber`/`PdfShareRoot`/`FromAddress`/`ConfigKey`）。**既定値をコードに持たせ、MainWeb の appsettings は変更しない**（steering「モジュール改変の原則」に準拠）。既定: `TestSendEnabled=true`・`TestFaxNumber=06-6487-1033`・`PdfShareRoot=\\OJIADM23120073\app_share\PrintAgent`・`FromAddress=material-noreply@example.co.jp`・`ConfigKey=Material`
    - `AddMaterialModule` で `Configure<FaxDispatchOptions>(configuration.GetSection("FaxDispatch"))` を呼ぶ（セクションが無ければコード既定が有効。将来オーバーライド可）
    - _Requirements: 8.1, 8.5, 8.6_

- [x] 2. 送信履歴エンティティ・DbContext・DDL・ドキュメント
  - [x] 2.1 TOrderDispatchLog エンティティを実装
    - `MaterialModule/Data/Entities/TOrderDispatchLog.cs` を新規作成（design.md のスキーマどおり）
    - `Id`/`ReferenceCode`/`DispatchType`/`QueueJobId`/`Recipient`/`ConfigKey`/`IsTestSend`/`CreatedAt`/`UpdatedAt`/`RowVersion`
    - `[Timestamp] RowVersion`、各列に `[Column]`/`[MaxLength]`/`[Required]` を付与
    - _Requirements: 9.1, 12.1, 12.2_

  - [x] 2.2 MaterialDbContext へ DbSet と複合一意インデックスを追加
    - `MaterialModule/Data/MaterialDbContext.cs` に `DbSet<TOrderDispatchLog> OrderDispatchLogs` を追加
    - `OnModelCreating` で `(ReferenceCode, DispatchType)` の複合一意インデックス `uq_t_order_dispatch_log_01` を定義
    - _Requirements: 9.1, 9.2, 12.1, 12.2_

  - [x] 2.3 t_order_dispatch_log の DDLスクリプトを作成（ユーザー実行）
    - `MaterialModule/Doc/sql/` に `t_order_dispatch_log` の CREATE TABLE スクリプトを作成
    - 列: `id`(IDENTITY,PK)/`reference_code`(nvarchar(50) NOT NULL)/`dispatch_type`(nvarchar(20) NOT NULL)/`queue_job_id`(int NULL)/`recipient`(nvarchar(255) NULL)/`config_key`(nvarchar(50) NULL)/`is_test_send`(bit NOT NULL)/`created_at`(datetime2 NOT NULL)/`updated_at`(datetime2 NOT NULL)/`row_version`(rowversion)
    - 複合一意制約 `uq_t_order_dispatch_log_01 (reference_code, dispatch_type)` を含める
    - スクリプト冒頭に「実行はユーザーが `db_material_dev` に対して行う」旨をコメントで明記
    - _Requirements: 9.1, 12.2_

  - [x] 2.4 テーブル定義書・ER図を更新
    - `MaterialModule/Doc/テーブル定義書.md` に `t_order_dispatch_log` の列名・日本語名・型・備考を追記
    - `MaterialModule/Doc/ER図.md` に `t_order_dispatch_log` と `reference_code`(発注番号グループ)・`queue_job_id`(`t_smtp_queue.id` 参照のみ) の関係を追記
    - _Requirements: 9.1, 12.2_

  - [x]* 2.5 エンティティ構造の単体テスト
    - `TOrderDispatchLog` に `[Timestamp] row_version` が存在し、`MaterialDbContext` で `(reference_code, dispatch_type)` の複合一意インデックスが構成されることを検証（SMOKE）
    - _Requirements: 12.1, 12.2_

- [x] 3. 送信投入サービスの純粋ロジック実装
  - [x] 3.1 IDispatchEnqueueService 定義と純粋静的メソッド群を実装
    - `MaterialModule/Services/IDispatchEnqueueService.cs`（`EnqueueOrderApprovalFaxAsync(List<TOrder>, CancellationToken)`）を作成
    - `MaterialModule/Services/DispatchEnqueueService.cs` に純粋ロジックを静的メソッドとして実装: `ExtractGroupKey`(発注番号→先頭3セグメント)・`ShouldDispatchFax`(OutputType 2/3 が1件以上で true)・`ResolveFaxRecipient`(`DestinationFax` 優先→`m_suppliers.Fax` フォールバック→空白なら null)・`BuildSubject`(`発注書 {グループ}（{会社名}）`、会社名なしは `発注書 {グループ}`)・`BuildBody`(定型本文)・`ResolveRecipientForSend`(テスト送信時はダミー番号へ上書き)・PDFファイル名構築(`order_{groupKey}_{yyyyMMddHHmmssfff}.pdf`)
    - _Requirements: 3.1, 4.1, 4.2, 4.3, 5.1, 5.2, 5.3, 6.3, 7.2, 7.3, 8.2, 8.3, 8.4, 8.5_

  - [x]* 3.2 送信要否判定のプロパティテスト
    - **Property 2: 送信要否はグループ内 OutputType に対する同値**
    - **Validates: Requirements 4.1, 4.2, 4.3**
    - 任意の `OutputType` 集合のグループを生成し、`ShouldDispatchFax` が「2 または 3 が1件以上」と同値であることを検証。`// Feature: order-approval-fax-mail, Property 2` タグ、100イテレーション以上

  - [x]* 3.3 宛先解決のプロパティテスト
    - **Property 4: 宛先解決の優先順位と無加工受け渡し**
    - **Validates: Requirements 5.1, 5.2, 5.3**
    - `DestinationFax`／`SupplierFax` の有無組合せを生成し、`DestinationFax` 非空→その値・空→`m_suppliers.Fax`、かつ正規化を施さずそのまま返すことを検証。`// Feature: order-approval-fax-mail, Property 4` タグ、100イテレーション以上

  - [x]* 3.4 テスト送信宛先上書きのプロパティテスト
    - **Property 8: テスト送信時の宛先上書き**
    - **Validates: Requirements 8.2, 8.3, 8.4, 8.5**
    - テスト有効/無効 × 任意実FAX番号を生成し、有効時はダミー番号・無効時は実FAX番号となる `ResolveRecipientForSend` を検証。`// Feature: order-approval-fax-mail, Property 8` タグ、100イテレーション以上

  - [x]* 3.5 PDFファイル名のプロパティテスト
    - **Property 11: 保管PDFファイル名はグループを含み一意である**
    - **Validates: Requirements 6.2, 6.3, 6.4**
    - 任意グループキー・複数時刻を生成し、フルパスが `PdfShareRoot` 配下・ファイル名がグループキーを含み・時刻差で異なるパスとなることを検証。`// Feature: order-approval-fax-mail, Property 11` タグ、100イテレーション以上

  - [x]* 3.6 本文構築の単体テスト
    - `BuildBody` が定型本文でありグループキーを含むことを検証（EXAMPLE）
    - _Requirements: 7.3_

- [x] 4. 送信投入サービス本体アルゴリズムの実装
  - [x] 4.1 DispatchEnqueueService 本体（グループ単位ループ・PDF生成保管・キュー投入・二重送信防止・エラー局所化）を実装
    - `DispatchEnqueueService.EnqueueOrderApprovalFaxAsync` を実装。コンストラクタ注入: `MaterialDbContext`/`IOrderPdfService`/`IMasterService`/`ISmtpQueueService`/`IOptions<FaxDispatchOptions>`/`ILogger`
    - 採番済み `OrderNo` のみ対象（Req2.3）→ `ExtractGroupKey` でグルーピング → グループ毎に独立 try/catch
    - `ShouldDispatchFax` が false ならスキップ・ログ（Req4.2）→ `t_order_dispatch_log` 照会で投入済みスキップ・ログ（Req9.2）→ 宛先解決不能スキップ・ログ（Req4.5/5.4）→ 差出人構築（`GetCompanyInfoAsync`、不能ならスキップ・ログ Req7.5）→ PDF生成（`GenerateGroupOrderPdfAsync`）・共有フォルダ保管（失敗スキップ・ログ Req6.6）→ 件名/本文/テスト送信宛先上書き → `EnqueueAsync(module:"material", configKey:"Material", ...)` → 成功後 `t_order_dispatch_log` 記録（一意制約違反 `DbUpdateException` は既投入として安全スキップ）
    - _Requirements: 1.3, 2.3, 3.2, 3.3, 4.4, 4.5, 4.6, 5.4, 6.1, 6.2, 6.4, 6.5, 6.6, 7.1, 7.4, 7.5, 8.1, 9.1, 9.2, 9.3, 10.1, 10.2, 10.3, 11.2, 12.3_

  - [x]* 4.2 採番済み発注のみ対象のプロパティテスト
    - **Property 1: 採番済み発注のみが送信対象**
    - **Validates: Requirements 2.3**
    - `OrderNo` 有無混在の発注リストを生成し、未採番発注がいかなる送信ジョブにも含まれないことを検証（モック/InMemory）。`// Feature: order-approval-fax-mail, Property 1` タグ、100イテレーション以上

  - [x]* 4.3 1グループ1ジョブ1PDFのプロパティテスト
    - **Property 3: 対象グループごとに1ジョブ・1PDF生成**
    - **Validates: Requirements 3.1, 3.2, 3.3, 6.1**
    - 多様な `OrderNo`（セグメント数差含む）の発注リストを生成し、一意対象グループ数＝投入ジョブ数＝`GenerateGroupOrderPdfAsync` 呼び出し回数を検証。`// Feature: order-approval-fax-mail, Property 3` タグ、100イテレーション以上

  - [x]* 4.4 宛先解決不能で非投入のプロパティテスト
    - **Property 5: 宛先解決不能なグループは投入されない**
    - **Validates: Requirements 4.5, 5.4**
    - `DestinationFax` と `m_suppliers.Fax` がともに空白/null のグループを生成し、送信ジョブ非投入＋ログ記録を検証。`// Feature: order-approval-fax-mail, Property 5` タグ、100イテレーション以上

  - [x]* 4.5 差出人・件名構築のプロパティテスト
    - **Property 6: 差出人と件名の構築**
    - **Validates: Requirements 7.1, 7.2**
    - 多様な会社情報・グループキーを生成し、差出人が会社/担当者（不能時はフォールバック差出人）から構築され、件名がグループキーを必ず含み会社名があれば含むことを検証。`// Feature: order-approval-fax-mail, Property 6` タグ、100イテレーション以上

  - [x]* 4.6 二重送信防止のプロパティテスト
    - **Property 7: 二重送信防止の冪等性**
    - **Validates: Requirements 9.1, 9.2, 9.3**
    - 同一グループへの複数回投入（別承認操作・同一操作内の重複発注）を生成し、`(reference_code, dispatch_type)` 一意制約により高々1件のみ投入・2回目以降スキップ＋ログを検証。`// Feature: order-approval-fax-mail, Property 7` タグ、100イテレーション以上

  - [x]* 4.7 接続プロファイルキー固定のプロパティテスト
    - **Property 9: 接続プロファイルキーは常に Material**
    - **Validates: Requirements 8.1, 8.5, 7.4**
    - テスト送信有効/無効を生成し、`config_key` が常に `Material`・`module` が常に `material` であることを検証。`// Feature: order-approval-fax-mail, Property 9` タグ、100イテレーション以上

  - [x]* 4.8 承認非伝播・グループ失敗局所化のプロパティテスト
    - **Property 10: 送信投入は承認に伝播せず、グループ失敗は局所化される**
    - **Validates: Requirements 4.6, 6.6, 7.5, 10.1, 10.2**
    - 一部グループで内部失敗（PDF生成失敗・差出人構築失敗・キュー投入例外）を注入し、例外が伝播せず正常完了・他グループ投入が継続することを検証。`// Feature: order-approval-fax-mail, Property 10` タグ、100イテレーション以上

  - [x]* 4.9 投入経路の単体テスト
    - 送信ジョブ投入が `ISmtpQueueService.EnqueueAsync` 経由のみで行われ、`t_smtp_queue` を直接操作しないこと・本サービスが `t_order_reports.fax_status` を書き換えないことを検証（モック）
    - _Requirements: 1.3, 4.4, 11.2_

  - [x]* 4.10 エッジ/エラーの単体テスト
    - PDF生成例外（Req6.6）・差出人構築不能（Req7.5）・宛先空白（Req4.5/5.4）で当該グループが投入されずログ記録され、処理が継続することを検証（EDGE_CASE）
    - _Requirements: 4.5, 6.6, 7.5_

- [x] 5. DI登録と承認処理への統合
  - [x] 5.1 MaterialModuleExtensions に DispatchEnqueueService を登録
    - `MaterialModule/Extensions/MaterialModuleExtensions.cs`（`AddMaterialModule`）に `services.AddScoped<IDispatchEnqueueService, DispatchEnqueueService>();` を追加
    - `ISmtpQueueService` は `AddCommonModule` で登録済みのためコンストラクタ注入で取得（新規登録不要）
    - _Requirements: 1.2_

  - [x] 5.2 ApprovalService へ送信投入を統合
    - `MaterialModule/Services/ApprovalService.cs` に `IDispatchEnqueueService` をコンストラクタ注入
    - 個別承認(`ApproveOrderAsync`)・一括承認(`ApproveOrdersAsync`)の双方で、承認状態の `SaveChangesAsync` 確定後・既存 `_printJobService.CreateOrderApprovalJobsAsync` 呼び出し近傍（直後）で `_dispatchEnqueueService.EnqueueOrderApprovalFaxAsync(orders)` を呼ぶ
    - 既存の印刷ジョブ作成呼び出しは削除・変更しない（印刷経路は不変）
    - _Requirements: 2.1, 2.2, 2.4, 11.1, 11.3, 12.3_

  - [x]* 5.3 DI解決の単体テスト
    - `IDispatchEnqueueService` と依存する `ISmtpQueueService` がDIコンテナで解決できることを検証（SMOKE）
    - _Requirements: 1.1, 1.2_

  - [x]* 5.4 統合点の単体テスト
    - `ApproveOrderAsync`／`ApproveOrdersAsync` 実行後に、`CreateOrderApprovalJobsAsync`（既存・印刷）と `EnqueueOrderApprovalFaxAsync`（新規・FAX）の双方が承認確定（`SaveChanges`）後の順序で呼ばれることを検証（モック）
    - _Requirements: 2.1, 2.2, 2.4, 11.1, 11.3, 12.3_

  - [x]* 5.5 設定バインドの単体テスト
    - `FaxDispatchOptions` が `appsettings` の `FaxDispatch` セクションからバインドされ、`TestFaxNumber=06-6487-1033`／無効番号設定が `recipient` に反映されることを検証（SMOKE）
    - _Requirements: 8.3, 8.4, 8.6_

- [x] 6. チェックポイント - 全テストを通す
  - すべてのテストが通ることを確認し、不明点があればユーザーに確認する。（ビルド・DDL適用・テスト実行はユーザー側）

- [x] 7. Spec を MaterialModule/Doc 側に同期
  - [x] 7.1 Spec を MaterialModule/Doc 側にコピー同期
    - 正本 `.kiro/specs/order-approval-fax-mail/` の requirements.md・design.md・tasks.md を `MaterialModule/Doc/specs/order-approval-fax-mail/` にコピー
    - _Requirements: （プロジェクトルール: Spec 2箇所配置）_

## Notes

- `*` 付きサブタスクは省略可能（テスト）で、MVP優先時はスキップできる。コア実装タスクには `*` を付けていない。
- 各タスクは要件番号を参照し、プロパティテストは design.md の Correctness Property 番号（Property 1〜11）を明示している。
- **ビルド・DBスキーマ適用(DDL)・実FAX送信・テスト実行はユーザー側で実施する**。タスクではコード/DDLファイルの作成・更新までを行い、Kiro からはビルド・DDL実行・実送信・テスト実行を行わない（project-rules.md準拠）。
- プロパティテストは FsCheck で各 Property を単一テストとして実装し、最低100イテレーション・`// Feature: order-approval-fax-mail, Property {n}` タグを付す。純粋ロジック（静的メソッド）は直接、アルゴリズムは外部依存（DB・PDF生成・キュー投入）をモック/InMemory に差し替えて検証する。
- 新規エンティティ `TOrderDispatchLog` は `row_version`(`[Timestamp]`) を持ち、`(reference_code, dispatch_type)` 複合一意制約で二重投入を防止する（排他制御・楽観的ロック方針に準拠）。
- DBスキーマ変更に伴い `テーブル定義書.md`・`ER図.md` を更新する（タスク2.4）。
- 既存印刷経路(`PrintJobService`→`t_order_reports`→PrintAgent)は削除・変更せず並行維持し、FAX送信は常に `t_smtp_queue` 経由に一本化する（既存経路の削除タスクは含めない）。
- 11個の Correctness Property はそれぞれ単一のプロパティテストとして実装する（Property 2/4/8/11 は純粋ロジック=タスク3、Property 1/3/5/6/7/9/10 はアルゴリズム=タスク4）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "2.1", "2.3", "2.4"] },
    { "id": 1, "tasks": ["2.2", "3.1"] },
    { "id": 2, "tasks": ["2.5", "3.2", "3.3", "3.4", "3.5", "3.6", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "4.4", "4.5", "4.6", "4.7", "4.8", "4.9", "4.10", "5.1", "5.2"] },
    { "id": 4, "tasks": ["5.3", "5.4", "5.5"] },
    { "id": 5, "tasks": ["7.1"] }
  ]
}
```
