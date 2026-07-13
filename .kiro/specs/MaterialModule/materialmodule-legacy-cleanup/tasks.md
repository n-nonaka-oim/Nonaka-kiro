# Implementation Plan: materialmodule-legacy-cleanup（移行残骸の撤去）

## Overview

design.md の撤去順（依存が浅い順）に、**1タスク＝独立して検証可能な小さな撤去**として進める。各タスクは削除前に「残存参照ゼロ」を grep で確認し、削除後はビルド可能を保つ。DB 物理 DROP はユーザー実行。

前提（全タスク共通）:
- 変更は MaterialModule 内＋導線解除SQL のみ。MainWeb/AuthModule/SharedCore/CommonModule 不変更。
- 各削除タスクの冒頭で対象シンボルの参照を再 grep し、想定外の参照があれば中止して提示。
- ビルド/テストはユーザー（Kiro は撤去・参照確認・診断確認まで）。
- Spec 正本は `.kiro/specs/MaterialModule/materialmodule-legacy-cleanup/`。

## Tasks

- [x] 1. 空ページディレクトリの削除（低リスク）（2026/07/13）
  - `Areas/Material/Pages` 配下の空dir を削除: `SmtpMonitor`・`PrintMonitor`・`FaxMonitor`・`PrintQueue`・`DeliveryMonitor`・`OrderRecommendation`（各 items=0 を再確認のうえ削除）
  - 残ページ＝Approvals/Delivery/Dispatches/Forecasts/JobQueue/MasterMaintenance/Mrp/OrderPlanning/Orders/Receivings/StockLedger/TankCheck。
  - _Requirements: 1.1, 1.2_

- [x] 2. JobQueue ページの廃止（2026/07/13）
  - [x] 2.1 `IOrderPdfService.GenerateGroupOrderPdfAsync` の呼び出し元を確認
    - **他利用あり＝`ApprovalReportPdfProvider`（現行 dispatch の発注承認PDF生成）が使用**。→ `IOrderPdfService`/`OrderPdfService` は**残す**。JobQueue ページのみ削除。
    - _Requirements: 2.3_
  - [x] 2.2 `Areas/Material/Pages/JobQueue/`（Index.cshtml・Index.cshtml.cs）を削除
    - 削除後、`OrderReports`/`TOrderReport` 参照は `Data/Entities/TOrderReport.cs`＋`MaterialDbContext` のみ（確認済）。
    - _Requirements: 2.1, 2.4_
  - [x] 2.3 導線解除SQL 作成 `MaterialModule/docs/sql/unregister_jobqueue_content.sql`（dbAuthTest・`area='Material'`/`page='JobQueue/Index'` の r_content_auth→m_content DELETE＋確認クエリ・実行はユーザー）
    - _Requirements: 2.2_

- [x] 3. 未使用エンティティ/DbSet 削除（移行済・実使用ゼロ）（2026/07/13）
  - 参照が定義+DbSet のみ（MaterialModule.Tests 参照ゼロ）を確認 → `Data/Entities/MSmtpConfig.cs`・`MSmtpAgentControl.cs`・`MPrintAgentControl.cs` 削除＋`MaterialDbContext` の `SmtpConfigs`/`SmtpAgentControls`/`PrintAgentControls` DbSet 3行削除。診断クリア。
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. デッドコード削除（撤去済みページの残骸）（2026/07/13）
  - [x] 4.1 `DeliveryMonitorDto`（Models/Dtos）削除＋`IOrderService.GetDeliveryMonitorListAsync` 宣言＋`OrderService` 実装（358–）削除。呼び出し元ゼロ確認。診断クリア。
    - _Requirements: 4.1, 4.3, 4.4_
  - [x] 4.2 `OrderRecommendationViewModel`（Models/ViewModels）削除。関連サービスメソッドは存在せず（自ファイルのみ）。残存参照0確認。
    - _Requirements: 4.2, 4.3, 4.4_

- [x] 5. TOrderReport のコード側退役（JobQueue 廃止後）（2026/07/13）
  - 参照が定義+DbSet のみを確認 → `Data/Entities/TOrderReport.cs` 削除＋`MaterialDbContext.OrderReports` DbSet 削除。診断クリア。
  - テーブル `t_order_reports` は保全（DROP しない・J-2）。
  - **テスト是正**（Req 3.2/5・ユーザー承認 a）: `Nonaka\MaterialModule.Tests\OrderApprovalFaxMail\DispatchEnqueueUnitTests.cs` の `Context.OrderReports` 参照（doc/assert/テスト名 `..._AndDoesNotTouchOrderReports`→`..._EnqueuesViaSmtpQueueOnly`）を除去。SmtpQueue 投入検証は維持。※`clnCoCore\MaterialModule.Tests`（slnCoCore 参照）は元からクリーン。
  - ⚠ 別途整理候補: `Nonaka\MaterialModule.Tests`（slnCoCore 未参照）と `clnCoCore\MaterialModule.Tests`（solution 参照）の二重（本 spec 範囲外）。
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 6. チェックポイント（ユーザー）- ビルド確認（2026/07/13・slnCoCore ビルドOK）
  - 撤去後も成功・現行ページに影響なしを確認。
  - _Requirements: 2.4, 3.3, 4.4, 5.3, 7.2_

- [x] 7. ドキュメント整合（2026/07/13）
  - `テーブル定義書.md`「重複テーブルの整理」にコード側撤去（cleanup 2026/07/13）を追記。ER図はテーブル構成不変のため変更なし（旧3テーブルは 07/03 反映済・t_order_reports は保全）。
  - `未実装案件一覧.md`：L 節（cleanup）追加・優先度表更新・J-1 を「DROP済(07/03)」に是正。
  - _Requirements: 8.1, 8.2_

- [ ] 8. チェックポイント（ユーザー）- DB / 導線の反映
  - JobQueue 導線解除SQL（2.3 `unregister_jobqueue_content.sql`）を dbAuthTest に適用（メニューから JobQueue 除去）
  - J-1: db_material_dev の旧3テーブルは **2026/07/03 DROP 済**（対応不要）
  - J-2: `t_order_reports` は保全期間終了後にユーザー判断で DROP（破壊的・要バックアップ）
  - _Requirements: 6.1, 6.2, 2.2_

## Notes

- 各削除は「参照ゼロ確認 → 削除 → 診断クリア」の順。想定外参照があれば中止・提示（Req 1.2/2.3/3.2/4.3）。
- `MPrintOutputPath`/`PrintOutputPaths` は現行使用のため**削除しない**（Req 7.1）。
- 旧 `publish/` 配下の残存はビルド成果物で対象外。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2.1", "3", "4.1", "4.2"] },
    { "id": 1, "tasks": ["2.2"] },
    { "id": 2, "tasks": ["2.3", "5"] },
    { "id": 3, "tasks": ["6"] },
    { "id": 4, "tasks": ["7"] },
    { "id": 5, "tasks": ["8"] }
  ]
}
```
