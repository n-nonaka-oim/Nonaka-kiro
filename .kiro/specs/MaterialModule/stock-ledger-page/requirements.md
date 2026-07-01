# 要件定義書

## はじめに

受払台帳ページ（StockLedger/Index）の機能仕様。品目別入出庫残高一覧として、指定期間内の全品目（またはマイナス在庫品目のみ）の計画・実績データを一覧表示する画面。左側に品目属性情報、右側に日別の入庫・出庫・在庫データテーブルを横並びで表示する。計画データのAJAX保存機能を備える。対象はMaterialModule内のRazor Pagesアプリケーション。

URL: /Material/StockLedger

## 用語集

- **StockLedger_Page**: MaterialModule/Areas/Material/Pages/StockLedger/Index に配置された受払台帳画面（品目別入出庫残高一覧）
- **TStockLedger**: 受払台帳エンティティ（t_stock_ledgers テーブル。RecordDate, ReceivedQty, ReceivedCount, DispatchedQty, DispatchedCount, StockQty, StockCount, CarriedQty, CarriedCount, Unit, UnitContentQty 等を保持）
- **TOrderForecast**: 発注予測エンティティ（t_order_forecasts テーブル。ForecastDate, ForecastOrderQty を保持）
- **TConsumptionForecast**: 消費予測エンティティ（t_consumption_forecasts テーブル。ForecastDate, ForecastQty を保持）
- **MItem**: 品目マスタエンティティ（m_items テーブル。Concentration, SpecificGravity, PackageTypeName, ContentQty, ContentUnit, WarehouseName, DefaultDeliveryDays を保持）
- **MPurchaseCondition**: 購買条件マスタエンティティ（m_purchase_conditions テーブル。DestinationName, MakerName, PurchaseType, SupplierCode を保持）
- **MSupplier**: 仕入先マスタエンティティ（m_suppliers テーブル。GrType を保持）
- **Left_Attribute_Area**: 品目属性情報を表示する左側エリア（罫線なし、幅220px）
- **Right_Data_Table**: 日別の計画・実績データを表示する右側テーブル（罫線あり、table-layout: fixed）
- **Plan_Columns**: 計画列（入庫・出庫・在庫）— クリーム色背景で視覚的に区別
- **Actual_Columns**: 実績列（入庫・出庫・在庫）— 通常背景
- **Summary_Row**: 品目グループごとの合計行（計）— table-warning スタイル

## 要件

### 要件 1: 期間フィルタ

**ユーザーストーリー:** 購買担当者として、表示期間を指定できることで、任意の期間の受払データを確認したい。

#### 受入基準

1. THE StockLedger_Page SHALL display a period filter with DateFrom and DateTo date input fields
2. THE DateFrom field SHALL default to the first day of the current month when no value is specified
3. THE DateTo field SHALL default to the last day of the current month when no value is specified
4. WHEN the "表示" button is clicked, THE StockLedger_Page SHALL reload with the specified period filter applied
5. THE DateFrom and DateTo parameters SHALL support GET binding (SupportsGet = true)

### 要件 2: 表示モードフィルタ

**ユーザーストーリー:** 購買担当者として、マイナス在庫品目のみを絞り込めることで、補充が必要な品目を素早く特定したい。

#### 受入基準

1. THE StockLedger_Page SHALL display a DisplayMode dropdown with two options: "在庫マイナスのみ" (value="minus") and "全件" (value="all")
2. THE DisplayMode dropdown SHALL default to "minus" (在庫マイナスのみ) when no value is specified
3. WHEN DisplayMode is "minus", THE StockLedger_Page SHALL display only item groups where FinalStockCount < 0 or FinalStockQty < 0
4. WHEN DisplayMode is "all", THE StockLedger_Page SHALL display all item groups regardless of stock level
5. THE DisplayMode parameter SHALL support GET binding (SupportsGet = true)

### 要件 3: レイアウト構造

**ユーザーストーリー:** 購買担当者として、品目属性とデータテーブルを横並びで確認できることで、品目情報を参照しながら入出庫データを把握したい。

#### 受入基準

1. THE StockLedger_Page SHALL display each item group as a d-flex horizontal layout with Left_Attribute_Area on the left and Right_Data_Table on the right
2. THE Left_Attribute_Area SHALL have a fixed width of 220px with no table borders (border-0 on all cells)
3. THE Right_Data_Table SHALL use table-bordered class with table-layout: fixed and be wrapped in a table-responsive container
4. THE Left_Attribute_Area SHALL use flex-shrink-0 to prevent width compression
5. THE Right_Data_Table SHALL use flex-grow-1 to fill remaining horizontal space
6. THE overall font size SHALL be 0.7rem for compact display
7. WHEN no item groups exist for the selected period and display mode, THE StockLedger_Page SHALL display "該当するデータはありません。"

### 要件 4: 左側属性エリア

**ユーザーストーリー:** 購買担当者として、品目の属性情報を一覧で確認できることで、発注判断に必要な情報を即座に把握したい。

#### 受入基準

1. THE Left_Attribute_Area SHALL display the following 12 attributes in order as label-value pairs:
   - 品目コード: ItemCode
   - 品目: ItemName
   - 仕入先: MPurchaseCondition.DestinationName
   - メーカー: MPurchaseCondition.MakerName
   - 濃度: MItem.Concentration (N1 format)
   - 比重: MItem.SpecificGravity (N2 format)
   - 購買: MSupplier.GrType (購買条件の仕入先コードから取得)
   - 在庫: MPurchaseCondition.PurchaseType (1="在庫", 2="預託")
   - 納期: MItem.DefaultDeliveryDays に "日" を付加
   - 荷姿: MItem.PackageTypeName
   - 入目: MItem.ContentQty と MItem.ContentUnit を結合 (例: "500KG")
   - 倉庫: MItem.WarehouseName
2. WHEN attribute data is not available (null), THE Left_Attribute_Area SHALL display "-" for that field
3. THE Left_Attribute_Area SHALL use a table with table-sm class, no borders, and each row height of 18px
4. THE label column SHALL use fw-bold class for emphasis

### 要件 5: 右側データテーブル — ヘッダー構造

**ユーザーストーリー:** 購買担当者として、計画と実績を明確に区別して確認できることで、計画と実績の乖離を視覚的に把握したい。

#### 受入基準

1. THE Right_Data_Table header SHALL use a 3-tier structure:
   - Tier 1: "年月日" (rowspan=3) | "計画" (colspan=6) | "実績" (colspan=6)
   - Tier 2: "入庫" (colspan=2) | "出庫" (colspan=2) | "在庫" (colspan=2) — repeated for both 計画 and 実績
   - Tier 3: "数量<br/>個数" | "単位" — repeated for each sub-column (6 pairs total)
2. THE column order SHALL be Plan (left) followed by Actual (right)
3. THE Plan_Columns header cells SHALL have background color #f5f0d0 (cream)
4. THE Actual_Columns header cells SHALL use the default table-light background

### 要件 6: 右側データテーブル — データ行

**ユーザーストーリー:** 購買担当者として、日別の数量と個数を同時に確認できることで、重量ベースと個数ベースの両方で在庫状況を把握したい。

#### 受入基準

1. EACH date entry SHALL be displayed as 2 rows: row 1 for quantity (数量, N3 format) and row 2 for count (個数, N0 format)
2. THE date cell (年月日) SHALL use rowspan=2 to span both rows, formatted as "yy/MM/dd"
3. THE Plan_Columns data cells SHALL have background color #fdfbf0 (light cream)
4. THE Actual_Columns data cells SHALL use the default (no background) style
5. THE unit column for row 1 (数量) SHALL display the item's Unit value (e.g., "KG", "L")
6. THE unit column for row 2 (個数) SHALL always display "個"
7. ALL numeric cells SHALL be right-aligned (text-end), unit cells SHALL be center-aligned (text-center)
8. THE Right_Data_Table SHALL use colgroup to fix column widths: 年月日=62px, 数値=70px, 単位=30px

### 要件 7: 合計行（計）

**ユーザーストーリー:** 購買担当者として、期間合計を確認できることで、品目ごとの入出庫総量と最終在庫を把握したい。

#### 受入基準

1. THE Right_Data_Table SHALL display a Summary_Row at the bottom of each item group's data rows
2. THE Summary_Row SHALL display "計" in the date column with rowspan=2
3. THE Summary_Row SHALL display totals for: 計画入庫合計, 計画出庫合計, 計画最終在庫, 実績入庫合計, 実績出庫合計, 実績最終在庫
4. THE Summary_Row SHALL use table-warning class and fw-bold for visual emphasis
5. THE Summary_Row SHALL follow the same 2-row pattern: row 1 for quantity totals (N3), row 2 for count totals (N0)

### 要件 8: 計画データの算出

**ユーザーストーリー:** 購買担当者として、計画在庫が自動計算されることで、計画入庫・出庫の変更が在庫推移に与える影響を即座に確認したい。

#### 受入基準

1. THE plan receipt data (PlanReceivedQty/PlanReceivedCount) SHALL be sourced from t_order_forecasts (ForecastOrderQty × UnitContentQty for Qty, ForecastOrderQty for Count)
2. THE plan dispatch data (PlanDispatchedQty/PlanDispatchedCount) SHALL be sourced from t_consumption_forecasts (Sum of ForecastQty per date × UnitContentQty for Qty, Sum of ForecastQty for Count)
3. THE plan stock (PlanStockQty/PlanStockCount) SHALL be calculated as a running total: CarriedQty/CarriedCount + cumulative PlanReceived − cumulative PlanDispatched
4. WHEN no forecast record exists for a specific date, THE plan receipt or dispatch value SHALL be 0

### 要件 9: 計画データのAJAX保存

**ユーザーストーリー:** 購買担当者として、計画入庫・出庫の値をページ上で直接保存できることで、計画変更を迅速に反映したい。

#### 受入基準

1. THE StockLedger_Page SHALL provide an OnPostSavePlanReceiptAsync AJAX handler that accepts a PlanCellSaveRequest (ItemId, Date, Qty)
2. WHEN OnPostSavePlanReceiptAsync is called, THE handler SHALL create or update the TOrderForecast record matching ItemId and ForecastDate
3. THE StockLedger_Page SHALL provide an OnPostSavePlanDispatchAsync AJAX handler that accepts a PlanCellSaveRequest (ItemId, Date, Qty)
4. WHEN OnPostSavePlanDispatchAsync is called, THE handler SHALL create or update the TConsumptionForecast record matching ItemId and ForecastDate
5. WHEN the save succeeds, THE handler SHALL return JSON { success: true }
6. WHEN the save fails, THE handler SHALL return JSON { success: false, message: errorMessage }

### 要件 10: 計画データのインライン編集UI（2026/05/27実装済み・未ビルド）

**ユーザーストーリー:** 購買担当者として、計画入庫・出庫セルをダブルクリックして直接編集できることで、Excel的な操作感で計画データを素早く更新したい。

#### 受入基準

1. WHEN a user double-clicks a plan receipt or plan dispatch quantity cell, THE StockLedger_Page SHALL replace the cell content with a number input field
2. THE input field SHALL display the current value in count (個数) units, pre-selected for immediate overwrite
3. WHEN the user presses Enter or the input loses focus, THE StockLedger_Page SHALL send a fetch POST to the corresponding save handler (SavePlanReceipt or SavePlanDispatch)
4. WHEN the user presses Escape, THE StockLedger_Page SHALL cancel the edit and restore the original value
5. WHEN the user presses Tab, THE StockLedger_Page SHALL commit the current edit and move to the next editable plan cell
6. WHEN the save succeeds, THE StockLedger_Page SHALL update the quantity cell (count × UnitContentQty, formatted N3) and the corresponding count cell (formatted N0)
7. WHEN the save succeeds, THE StockLedger_Page SHALL recalculate all plan stock cells (quantity and count) for the same item as a running total from carried forward
8. THE StockLedger_Page SHALL display visual feedback: blue background during save, green flash on success (0.8s), alert on failure
9. THE plan stock cells (計画在庫) SHALL NOT be editable (auto-calculated)
10. THE count row cells SHALL NOT be editable (auto-calculated from quantity ÷ UnitContentQty)
11. THE actual columns (実績) and carried forward columns (繰越) SHALL NOT be editable

### 要件 11: 認可制御

**ユーザーストーリー:** システム管理者として、受払台帳ページへのアクセスが権限のあるユーザーに限定されることで、在庫データの不正閲覧を防止したい。

#### 受入基準

1. THE StockLedger_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy
