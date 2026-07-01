# Implementation Plan: Order Planning Dashboard（発注計画ダッシュボード）

## Overview

既存の StockLedger・MRP・OrderRecommendation の3ページ機能を1画面に統合する新規 Razor Page を実装する。ASP.NET Core Razor Pages パターン、Bootstrap 5 + vanilla JavaScript、FsCheck.Xunit による Property-Based Testing を採用する。

## Tasks

- [x] 1. ViewModel・リクエストモデルの作成
  - [x] 1.1 AlertSummaryViewModel と OrderPlanningItemViewModel を作成する
    - `MaterialModule/Models/ViewModels/AlertSummaryViewModel.cs` を作成
    - `MaterialModule/Models/ViewModels/OrderPlanningItemViewModel.cs` を作成
    - RedCount, OrangeCount, YellowCount, TotalCount プロパティを定義
    - ItemId, ItemCode, ItemName, AlertLevel, CurrentStockCount, SafetyStockQty, RecommendedOrderQty, ForecastOrderDate, LeadTimeDays プロパティを定義
    - _Requirements: 3.1, 4.1, 4.2, 4.4_

  - [x] 1.2 OrderEntryCreateRequest モデルを作成する
    - `MaterialModule/Models/ViewModels/OrderEntryCreateRequest.cs` を作成
    - ItemId, Qty, DeliveryDate プロパティを定義
    - _Requirements: 7.5_

- [x] 2. PageModel の実装（Index.cshtml.cs）
  - [x] 2.1 IndexModel クラスの基本構造と OnGetAsync ハンドラを実装する
    - `MaterialModule/Areas/Material/Pages/OrderPlanning/Index.cshtml.cs` を作成
    - primary constructor DI で IAlertService, IOrderService, IMasterService, MaterialDbContext を注入
    - `[Authorize(Policy = "DbPermissionCheck")]` と `[IgnoreAntiforgeryToken]` を付与
    - YearMonth バインドプロパティ（SupportsGet = true）を定義
    - OnGetAsync: YearMonth パース → DateFrom/DateTo 算出、AlertService からアラート取得、AlertSummary 集計、AlertItems リスト構築（フィルタリング + ソート）
    - YearMonth 未指定時は当月をデフォルト設定
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 4.1, 4.2, 4.3, 4.4_

  - [x] 2.2 OnGetLedgerPartialAsync ハンドラを実装する
    - 品目ID を受け取り、t_stock_ledgers, t_order_forecasts, t_consumption_forecasts, t_orders (status 30-50) をクエリ
    - StockLedgerItemGroup を構築し PlanStock 累計計算を実行
    - 品目属性情報（m_items + m_purchase_conditions）を取得
    - `_LedgerPartial` Partial View を返却
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 2.3 OnPostSavePlanReceiptAsync / OnPostSavePlanDispatchAsync ハンドラを実装する
    - PlanCellSaveRequest を [FromBody] で受け取り
    - BeginTransactionAsync でトランザクション開始
    - TOrderForecast / TConsumptionForecast の Upsert 処理
    - DbUpdateConcurrencyException キャッチ → ロールバック + エラーメッセージ返却
    - 成功時: `{ success: true }` を JSON 返却
    - _Requirements: 6.2, 6.6, 8.1, 8.2_

  - [x] 2.4 OnPostCreateOrderEntryAsync ハンドラを実装する
    - OrderEntryCreateRequest を [FromBody] で受け取り
    - サーバー側バリデーション: qty > 0, deliveryDate 非空
    - IOrderService.AddEntryAsync を呼び出し（OrderStatus=10, OrderType="manual"）
    - トランザクション管理 + エラーハンドリング
    - 成功時: `{ success: true, orderId, message }` を JSON 返却
    - _Requirements: 7.5, 7.6, 7.7, 7.8, 8.3_

- [x] 3. Checkpoint - 基本ロジック確認
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. メインページ View の実装（Index.cshtml）
  - [x] 4.1 Index.cshtml のレイアウト全体を実装する
    - `MaterialModule/Areas/Material/Pages/OrderPlanning/Index.cshtml` を作成
    - `<partial name="_MaterialStyles" />` をページ先頭に追加
    - container-fluid に `font-size: 0.8rem` を設定
    - sticky-top ヘッダー: 年月 input[type=month] + 表示ボタン + Action_Bar（初期 d-none）
    - Alert_Bar: Red/Orange/Yellow の件数バッジ表示
    - 2カラムレイアウト: col-3（Item_List_Panel）+ col-9（Ledger_Panel）
    - Item_List_Panel: AlertItems をループ表示（アラート色、品目コード、品目名、現在庫、推奨発注数量）
    - Ledger_Panel: 初期状態は「品目を選択してください」プレースホルダー
    - Action_Bar: 品目名表示、数量入力、納期入力、発注エントリ作成ボタン
    - _Requirements: 1.1, 1.4, 2.1, 3.1, 3.3, 4.2, 4.5, 5.5, 7.1, 7.2, 7.3, 7.4, 9.2, 9.3_

  - [x] 4.2 _LedgerPartial.cshtml を実装する
    - `MaterialModule/Areas/Material/Pages/OrderPlanning/_LedgerPartial.cshtml` を作成
    - 品目属性ヘッダー（納入先、メーカー、濃度、比重、GR区分、購買区分、荷姿、内容量、倉庫、納期日数）
    - 日別テーブル: 繰越、計画入庫、計画出庫、計画在庫、入庫実績、出庫実績、在庫 カラム
    - テーブルに `font-size: 0.75rem` を設定
    - 計画セル（Plan_Cell）に `data-*` 属性を付与（itemId, date, type, editable）
    - 確定発注セル（status 30-50）は read-only スタイル適用
    - _Requirements: 5.2, 5.3, 6.5, 9.1_

- [x] 5. クライアントサイド JavaScript の実装
  - [x] 5.1 orderPlanning.js の基本構造と品目選択機能を実装する
    - `MaterialModule/wwwroot/js/orderPlanning.js` を作成
    - OrderPlanning オブジェクト定義（selectedItemId 状態管理）
    - selectItem(itemId): fetch GET → `#ledger-panel` の innerHTML 置換
    - Action_Bar の表示切替（d-none 除去、品目名・推奨数量セット）
    - 品目行のアクティブ状態ハイライト
    - _Requirements: 5.1, 7.1, 7.2_

  - [x] 5.2 インライン編集機能（Plan_Cell 編集）を実装する
    - enableCellEdit(cell): ダブルクリック → input 変換
    - saveCellEdit(cell, type): POST SavePlanReceipt/SavePlanDispatch → 成功時 highlightCell
    - cancelCellEdit(cell): Escape → 元の値に復元
    - recalculateRunningTotal(): CarriedCount + Σ(PlanReceived) - Σ(PlanDispatched) の累計再計算
    - handleTabNavigation(e): Tab キーで次の編集可能セルへ移動
    - エラー時: セル値復元 + エラーメッセージ表示
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6, 6.7, 9.4_

  - [x] 5.3 発注エントリ作成機能を実装する
    - createOrderEntry(): バリデーション（qty > 0, deliveryDate 非空）→ POST CreateOrderEntry
    - validateOrderQty / validateDeliveryDate 関数
    - 成功時: showMessage + Item_List_Panel リフレッシュ
    - 失敗時: エラーメッセージ toast 表示
    - ajaxPost ヘルパー関数（共通エラーハンドリング）
    - _Requirements: 7.5, 7.6, 7.7, 7.8_

- [x] 6. Checkpoint - UI 動作確認
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Property-Based Tests（FsCheck.Xunit）
  - [x]* 7.1 Property 1: 年月→日付範囲変換の正確性テストを作成する
    - **Property 1: 年月→日付範囲変換の正確性**
    - **Validates: Requirements 2.3**
    - ランダムな有効年月 (1-12月, 1900-2100年) を生成し、DateFrom が月初、DateTo が月末であることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.2 Property 2: アラート件数集計の整合性テストを作成する
    - **Property 2: アラート件数集計の整合性**
    - **Validates: Requirements 3.1**
    - ランダムな StockAlertDto リストを生成し、Red/Orange/Yellow の件数が正しく集計されることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.3 Property 3: 品目フィルタリングと推奨発注数量テストを作成する
    - **Property 3: 品目フィルタリングと推奨発注数量**
    - **Validates: Requirements 4.1, 4.4**
    - ランダムな stock/safety 値ペアを生成し、フィルタ条件と推奨数量計算を検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.4 Property 4: 品目リストのソート順序テストを作成する
    - **Property 4: 品目リストのソート順序**
    - **Validates: Requirements 4.3**
    - ランダムな AlertLevel + ItemCode リストを生成し、ソート結果が Red > Orange > Yellow 順かつ同レベル内 ItemCode 昇順であることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.5 Property 5: PlanStock 累計計算の不変条件テストを作成する
    - **Property 5: PlanStock 累計計算の不変条件**
    - **Validates: Requirements 6.3**
    - ランダムな CarriedCount + 行シーケンスを生成し、累計計算が CarriedCount + Σ(Received) - Σ(Dispatched) と一致することを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.6 Property 6: 確定発注セルの編集不可制約テストを作成する
    - **Property 6: 確定発注セルの編集不可制約**
    - **Validates: Requirements 6.5**
    - ランダムな OrderStatus 値を生成し、30-50 の範囲内なら read-only、範囲外なら editable であることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.7 Property 7: 発注エントリ作成の不変条件テストを作成する
    - **Property 7: 発注エントリ作成の不変条件**
    - **Validates: Requirements 7.5**
    - ランダムな正の数量 + 有効日付を生成し、作成結果が常に OrderStatus=10, OrderType="manual" であることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

  - [x]* 7.8 Property 8: 数量バリデーション（非正値の拒否）テストを作成する
    - **Property 8: 数量バリデーション（非正値の拒否）**
    - **Validates: Requirements 7.7**
    - ランダムな非正の decimal 値を生成し、バリデーションエラーが返却されることを検証
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningPropertyTests.cs` に実装

- [x] 8. Unit Tests（xUnit + Moq）
  - [x]* 8.1 PageModel の Unit Tests を作成する
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningUnitTests.cs` に実装
    - DefaultYearMonth_WhenNull_ReturnsCurrentMonth
    - EmptyAlertList_ShowsNoAlertMessage
    - NoItemsBelowSafety_ShowsSufficientMessage
    - ConcurrencyConflict_ReturnsErrorMessage
    - EmptyDeliveryDate_ReturnsValidationError
    - NullItemId_ReturnsError
    - _Requirements: 2.2, 3.3, 4.5, 6.6, 7.7, 7.8, 8.2_

- [x] 9. Integration Tests
  - [x]* 9.1 Integration Tests を作成する
    - `MaterialModule.Tests/OrderPlanning/OrderPlanningIntegrationTests.cs` に実装
    - UnauthorizedAccess_RedirectsToLogin
    - LedgerPartial_ReturnsHtmlForValidItem
    - SavePlanReceipt_UpsertsForecast
    - CreateOrderEntry_InsertsOrderRecord
    - ConcurrentSave_DetectsConflict
    - _Requirements: 1.2, 1.3, 5.1, 6.2, 7.5, 8.1, 8.2, 8.3_

- [x] 10. Final checkpoint - 全テスト通過確認
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- タスクに `*` マークが付いたものはオプションであり、MVP 優先時はスキップ可能
- 各タスクは対応する Requirements を参照しトレーサビリティを確保
- Checkpoint タスクで段階的な品質確認を実施
- Property Tests は FsCheck.Xunit を使用し、最低100回のイテレーションで検証
- 既存サービス（IAlertService, IOrderService, IMasterService）のインターフェースは変更しない
- 既存ページ（StockLedger, MRP, OrderRecommendation）には影響を与えない

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4"] },
    { "id": 3, "tasks": ["4.1", "5.1"] },
    { "id": 4, "tasks": ["4.2", "5.2", "5.3"] },
    { "id": 5, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8"] },
    { "id": 6, "tasks": ["8.1", "9.1"] }
  ]
}
```
