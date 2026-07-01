# 要件定義書

## はじめに

タンク残量チェックページ（/Material/TankCheck）の機能仕様。タンクマスタ（m_tanks）に登録されたアクティブなタンクに対して、日次の残量チェック記録（残数量、比重、外観チェック、備考）を入力・保存する画面。対象品目は m_items.warehouse_code の先頭2桁が「15」の品目。タンクマスタは品目マスタから自動生成し、日次チェックデータはAJAXで行単位保存する。対象はMaterialModule内のRazor Pagesアプリケーション。

URL: /Material/TankCheck

## 用語集

- **TankCheck_Page**: MaterialModule/Areas/Material/Pages/TankCheck/Index に配置されたタンク残量チェック画面
- **MTank**: タンクマスタエンティティ（m_tanks テーブル。TankNo, TankName, ItemCode, ItemName, Capacity, Agitation, IsActive を保持）
- **TTankCheck**: 日次チェック記録エンティティ（t_tank_checks テーブル。TankId, CheckDate, CheckedBy, RemainingQty, SpecificGravity, AppearanceCheck, Remarks を保持）
- **MItem**: 品目マスタエンティティ（m_items テーブル。WarehouseCode, WarehouseName, ItemCode, ItemName を保持）
- **Tank_Target_Item**: m_items.warehouse_code の先頭2桁が「15」である品目
- **Check_Date_Selector**: 日付選択コントロール（デフォルト当日）
- **Tank_List_Table**: アクティブなタンク一覧と日次チェックデータを表示するテーブル
- **Row_Save**: 行単位のAJAX保存操作

## 要件

### 要件 1: タンクマスタの自動生成

**ユーザーストーリー:** システム管理者として、品目マスタからタンクマスタを自動生成できることで、手動登録の手間を省き、品目マスタとの整合性を保ちたい。

#### 受入基準

1. THE TankCheck_Page SHALL provide a mechanism to generate MTank records from MItem records where WarehouseCode starts with "15"
2. WHEN generating MTank records, THE system SHALL group Tank_Target_Item records by WarehouseCode and WarehouseName to create unique tank entries
3. WHEN generating an MTank record, THE system SHALL set TankNo to WarehouseCode, TankName to WarehouseName, ItemCode to the grouped item's ItemCode, and ItemName to the grouped item's ItemName
4. WHEN an MTank record already exists with the same TankNo, THE system SHALL skip creation for that tank to prevent duplicates
5. THE generated MTank records SHALL have IsActive set to true, and Capacity and Agitation set to null (to be configured manually later)

### 要件 2: 日付選択フィルタ

**ユーザーストーリー:** 担当者として、チェック対象日を選択できることで、当日以外の日付のチェック記録も入力・確認したい。

#### 受入基準

1. THE TankCheck_Page SHALL display a Check_Date_Selector with a date input field
2. THE Check_Date_Selector SHALL default to the current date when no value is specified
3. WHEN the date is changed, THE TankCheck_Page SHALL reload the tank list with check data for the selected date
4. THE CheckDate parameter SHALL support GET binding (SupportsGet = true)

### 要件 3: タンク一覧表示

**ユーザーストーリー:** 担当者として、全アクティブタンクの一覧を確認できることで、チェック対象のタンクを漏れなく把握したい。

#### 受入基準

1. THE TankCheck_Page SHALL display all MTank records where IsActive is true in the Tank_List_Table
2. THE Tank_List_Table SHALL display the following columns: タンクNo (TankNo), タンク名 (TankName), 品目コード (ItemCode), 品目名称 (ItemName), 容量 (Capacity), 攪拌 (Agitation), 残数量 (RemainingQty), 比重 (SpecificGravity), 外観 (AppearanceCheck), 備考 (Remarks), 担当者 (CheckedBy), 操作
3. THE Tank_List_Table SHALL use table-bordered and table-sm classes with font-size 0.75rem
4. WHEN a TTankCheck record exists for the selected date and tank, THE Tank_List_Table SHALL display the saved values in the corresponding input fields
5. WHEN no TTankCheck record exists for the selected date and tank, THE Tank_List_Table SHALL display empty input fields for data entry

### 要件 4: 日次チェックデータ入力

**ユーザーストーリー:** 担当者として、各タンクの残数量・比重・外観チェック・備考を入力できることで、日次の点検記録を正確に残したい。

#### 受入基準

1. THE Tank_List_Table SHALL provide a numeric input field for RemainingQty (残数量) for each tank row
2. THE Tank_List_Table SHALL provide a numeric input field for SpecificGravity (比重) for each tank row
3. THE Tank_List_Table SHALL provide a select dropdown for AppearanceCheck (外観チェック) with options: "" (未選択), "OK", "NG"
4. THE Tank_List_Table SHALL provide a text input field for Remarks (備考, maxlength=50) for each tank row
5. THE CheckedBy (担当者) field SHALL be automatically set to the currently logged-in user's name and displayed as read-only text

### 要件 5: AJAX行単位保存

**ユーザーストーリー:** 担当者として、各タンクのチェックデータを行単位で即座に保存できることで、入力途中でもデータを失わずに作業を進めたい。

#### 受入基準

1. THE Tank_List_Table SHALL provide a "保存" button in the 操作 column for each tank row
2. WHEN the "保存" button is clicked, THE TankCheck_Page SHALL send a fetch POST request with the row's data (TankId, CheckDate, RemainingQty, SpecificGravity, AppearanceCheck, Remarks)
3. WHEN no TTankCheck record exists for the specified TankId and CheckDate, THE handler SHALL create a new TTankCheck record
4. WHEN a TTankCheck record already exists for the specified TankId and CheckDate, THE handler SHALL update the existing record
5. WHEN the save succeeds, THE handler SHALL return JSON { success: true, rowVersion: newRowVersion } and the TankCheck_Page SHALL display a brief success indication on the row
6. WHEN the save fails due to a concurrency conflict, THE handler SHALL return JSON { success: false, message: "他のユーザーが先に更新しました。画面を再読み込みしてください。" }
7. IF an unexpected error occurs during save, THEN THE handler SHALL return JSON { success: false, message: errorDescription }
8. THE save handler SHALL use BeginTransactionAsync for data integrity

### 要件 6: 排他制御

**ユーザーストーリー:** システム管理者として、同時編集時にデータの整合性が保たれることで、複数担当者が同時にチェック入力しても正確なデータを維持したい。

#### 受入基準

1. THE TTankCheck entity SHALL include a RowVersion column with the [Timestamp] attribute for optimistic concurrency control
2. WHEN saving a TTankCheck record, THE handler SHALL check the RowVersion to detect concurrent modifications
3. WHEN a DbUpdateConcurrencyException occurs, THE handler SHALL return a concurrency conflict error response
4. THE TankCheck_Page SHALL send the current RowVersion value with each save request for conflict detection
5. WHEN the save succeeds, THE TankCheck_Page SHALL update the stored RowVersion on the client side with the returned newRowVersion

### 要件 7: 認可制御

**ユーザーストーリー:** システム管理者として、タンク残量チェックページへのアクセスが権限のあるユーザーに限定されることで、データの不正操作を防止したい。

#### 受入基準

1. THE TankCheck_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy

### 要件 8: ページレイアウトとスタイル

**ユーザーストーリー:** 担当者として、統一されたレイアウトで画面が表示されることで、他のMaterialModuleページと同じ操作感で作業したい。

#### 受入基準

1. THE TankCheck_Page SHALL include `<partial name="_MaterialStyles" />` at the top of the page
2. THE TankCheck_Page SHALL use a container with class "container-fluid mt-3 px-4 material-page" and style "font-size: 0.8rem;"
3. THE page title SHALL be displayed as `<h5 class="mb-2">タンク残量チェック</h5>`
4. THE Tank_List_Table SHALL use style "font-size: 0.75rem;" for compact display
5. WHEN no active tanks exist, THE TankCheck_Page SHALL display "アクティブなタンクが登録されていません。"
