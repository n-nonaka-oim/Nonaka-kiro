# Requirements Document

## Introduction

発注計画（OrderPlanning）ダッシュボードは、StockLedger（受払台帳）、MRP（発注予測）、OrderRecommendation（発注推奨）の3ページを統合した新規ページである。発注者が1画面で在庫不足品目の確認、受払台帳の閲覧・編集、発注エントリ作成までを完結できる日常業務のメイン画面として機能する。

URL: `/Material/OrderPlanning`

## Glossary

- **Order_Planning_Page**: 発注計画ダッシュボードページ（/Material/OrderPlanning）
- **Alert_Bar**: 在庫不足品目のサマリを表示するアラートバーコンポーネント
- **Item_List_Panel**: 不足品目一覧を表示する左パネルコンポーネント
- **Ledger_Panel**: 選択品目の受払台帳を表示する右パネルコンポーネント
- **Action_Bar**: 発注アクション（数量変更・納期入力・発注エントリ作成）を行うヘッダー内コンポーネント
- **Alert_Service**: IAlertServiceインターフェースを実装するサービス。safety_stock_qty割れ品目を検出しアラートレベル（Red/Orange/Yellow）を返す
- **Order_Service**: IOrderServiceインターフェースを実装するサービス。発注エントリの作成・管理を行う
- **Stock_Ledger**: t_stock_ledgersテーブルに格納される品目別日別の入出庫残高データ
- **Order_Forecast**: t_order_forecastsテーブルに格納される発注予測データ
- **Consumption_Forecast**: t_consumption_forecastsテーブルに格納される消費予測データ
- **Safety_Stock_Qty**: 品目マスタ（m_items）に設定される安全在庫数量。現在の発注判定基準
- **Alert_Level**: 在庫状態を示すレベル。Red（マイナス在庫・即時対応）、Orange（安全在庫割れ・要発注）、Yellow（発注期限間近・注意）
- **Plan_Cell**: 受払台帳内の計画入庫/計画出庫セル。ダブルクリックで編集可能

## Requirements

### Requirement 1: ページ表示と認可

**User Story:** As a 発注担当者, I want to 発注計画ページにアクセスする, so that 在庫状況の確認と発注手配を1画面で行える

#### Acceptance Criteria

1. WHEN a user navigates to `/Material/OrderPlanning`, THE Order_Planning_Page SHALL render the page with header, Alert_Bar, Item_List_Panel, and Ledger_Panel sections
2. THE Order_Planning_Page SHALL enforce authorization using the `DbPermissionCheck` policy
3. WHEN an unauthorized user accesses the page, THE Order_Planning_Page SHALL redirect the user to the login page
4. THE Order_Planning_Page SHALL apply the material-page font size rules (container 0.8rem, tables 0.75rem, title h5)

### Requirement 2: 年月選択と表示期間

**User Story:** As a 発注担当者, I want to 表示する年月を選択する, so that 任意の月の在庫状況を確認できる

#### Acceptance Criteria

1. THE Order_Planning_Page SHALL display a month-type input field and a display button in the header area
2. WHEN the page loads without a specified year-month, THE Order_Planning_Page SHALL default to the current year-month
3. WHEN the user selects a year-month and clicks the display button, THE Order_Planning_Page SHALL reload the page data for the selected month (1st day to last day of month)
4. THE Order_Planning_Page SHALL retain the selected year-month value after page reload

### Requirement 3: アラートバー表示

**User Story:** As a 発注担当者, I want to 在庫不足品目のサマリを一目で確認する, so that 対応の優先度を即座に判断できる

#### Acceptance Criteria

1. WHEN the page loads, THE Alert_Bar SHALL display the count of items for each Alert_Level: Red（🔴即時対応 N件）, Orange（🟠要発注 N件）, Yellow（🟡注意 N件）
2. THE Alert_Bar SHALL retrieve alert data from the Alert_Service
3. WHEN no items have alerts, THE Alert_Bar SHALL display a message indicating no alerts exist

### Requirement 4: 品目リスト表示

**User Story:** As a 発注担当者, I want to 在庫不足品目の一覧を確認する, so that どの品目に対応が必要か把握できる

#### Acceptance Criteria

1. WHEN the page loads, THE Item_List_Panel SHALL display a scrollable list of items where current stock is at or below Safety_Stock_Qty
2. THE Item_List_Panel SHALL display each item with: Alert_Level color indicator, item code, item name, current stock count (個数), and recommended order quantity (個数)
3. THE Item_List_Panel SHALL sort items by Alert_Level priority (Red first, then Orange, then Yellow) and then by item code
4. THE Item_List_Panel SHALL calculate recommended order quantity as Safety_Stock_Qty minus current stock count for each item
5. WHEN no items are below Safety_Stock_Qty, THE Item_List_Panel SHALL display a message indicating all items have sufficient stock

### Requirement 5: 品目選択と受払台帳表示

**User Story:** As a 発注担当者, I want to 品目をクリックして受払台帳を確認する, so that 選択品目の日別在庫推移を詳細に把握できる

#### Acceptance Criteria

1. WHEN the user clicks an item in the Item_List_Panel, THE Ledger_Panel SHALL display the Stock_Ledger for the selected item via AJAX partial update (no full page reload)
2. THE Ledger_Panel SHALL display the same layout as the existing StockLedger page for a single item (daily rows with carried, plan received, plan dispatched, plan stock, received, dispatched, stock columns)
3. THE Ledger_Panel SHALL display item attribute information (destination, maker, concentration, specific gravity, GR type, purchase type, package type, content, warehouse, delivery days) in a compact header area above the ledger table
4. THE Ledger_Panel SHALL retrieve data from t_stock_ledgers, t_order_forecasts, t_consumption_forecasts, and t_orders (status 30-50) for the selected year-month period
5. WHEN no item is selected, THE Ledger_Panel SHALL display a placeholder message prompting the user to select an item

### Requirement 6: 計画データのインライン編集

**User Story:** As a 発注担当者, I want to 計画入庫・計画出庫の数値を直接編集する, so that 発注計画を柔軟に調整できる

#### Acceptance Criteria

1. WHEN the user double-clicks a Plan_Cell (plan received or plan dispatched) that is not linked to a confirmed order, THE Ledger_Panel SHALL convert the cell to an editable input field
2. WHEN the user presses Enter or the input loses focus, THE Ledger_Panel SHALL save the edited value via AJAX POST to the existing SavePlanReceipt or SavePlanDispatch handler
3. WHEN the save succeeds, THE Ledger_Panel SHALL update the plan stock running total for all subsequent rows without full page reload
4. WHEN the user presses Escape, THE Ledger_Panel SHALL cancel the edit and restore the original value
5. WHEN a Plan_Cell is linked to a confirmed order (status 30-50), THE Ledger_Panel SHALL prevent editing and display the cell as read-only
6. IF the AJAX save fails, THEN THE Ledger_Panel SHALL display an error message and restore the original cell value
7. THE Ledger_Panel SHALL support Tab key navigation between editable Plan_Cells

### Requirement 7: 発注アクションバー

**User Story:** As a 発注担当者, I want to 選択品目の発注エントリを作成する, so that 在庫不足品目の発注手配を即座に行える

#### Acceptance Criteria

1. WHEN an item is selected in the Item_List_Panel, THE Action_Bar SHALL become visible in the header area
2. THE Action_Bar SHALL display the recommended order quantity (Safety_Stock_Qty minus current stock) as the default value
3. THE Action_Bar SHALL provide an editable quantity input field allowing the user to change the order quantity
4. THE Action_Bar SHALL provide a delivery date input field
5. WHEN the user clicks the "発注エントリ作成" button with valid quantity and delivery date, THE Action_Bar SHALL create a new order entry in t_orders with status=10 and order_type='manual'
6. WHEN the order entry is created successfully, THE Action_Bar SHALL display a success message and update the Item_List_Panel to reflect the new order
7. IF the quantity is zero or negative, THEN THE Action_Bar SHALL display a validation error and prevent submission
8. IF the delivery date is empty, THEN THE Action_Bar SHALL display a validation error and prevent submission

### Requirement 8: データ整合性と排他制御

**User Story:** As a 発注担当者, I want to データの整合性が保たれる, so that 同時操作による不整合が発生しない

#### Acceptance Criteria

1. WHEN saving plan cell edits, THE Order_Planning_Page SHALL use database transactions (BeginTransactionAsync) to ensure data integrity
2. IF a concurrent modification is detected during plan cell save, THEN THE Order_Planning_Page SHALL display the message "他のユーザーが先に更新しました。画面を再読み込みしてください。"
3. WHEN creating an order entry, THE Order_Planning_Page SHALL use a database transaction to ensure the order record is created atomically
4. THE Order_Planning_Page SHALL include row_version columns on new entities for optimistic locking

### Requirement 9: パフォーマンスとUX

**User Story:** As a 発注担当者, I want to ページが素早く応答する, so that 業務効率が低下しない

#### Acceptance Criteria

1. WHEN the user clicks an item in the Item_List_Panel, THE Ledger_Panel SHALL complete the AJAX partial update within 2 seconds under normal database load
2. THE Item_List_Panel SHALL remain scrollable independently of the Ledger_Panel
3. THE Order_Planning_Page SHALL keep the header and Action_Bar fixed at the top of the viewport during scrolling
4. WHEN a plan cell edit is saved, THE Ledger_Panel SHALL provide visual feedback (brief highlight) to confirm the save completed

### Requirement 10: 既存ページとの共存

**User Story:** As a システム管理者, I want to 既存ページ（StockLedger, MRP, OrderRecommendation）が引き続き利用可能である, so that 全品目一覧・印刷・MRP再計算の機能が維持される

#### Acceptance Criteria

1. THE Order_Planning_Page SHALL not modify or remove the existing StockLedger, MRP, or OrderRecommendation pages
2. THE Order_Planning_Page SHALL reuse existing service interfaces (IAlertService, IRequirementCalculationService, IMasterService, IOrderService) without modifying their contracts
3. THE Order_Planning_Page SHALL reuse the existing SavePlanReceipt and SavePlanDispatch handler logic for plan cell editing
