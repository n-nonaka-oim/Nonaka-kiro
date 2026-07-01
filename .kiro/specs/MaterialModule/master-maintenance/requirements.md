# 要件定義書

## はじめに

マスタメンテナンスページ（MasterMaintenance/Index）の機能仕様。複数マスタテーブルをタブ切り替えで一覧表示・編集する管理画面。品目マスタの一覧テーブルは表示専用（読み取り専用）とし、登録・編集はすべて品目モーダル（itemModal）に集約する。その他のタブ（仕入先・購買条件・荷姿・倉庫・用途2/用途3）の仕様は従来どおり。対象はMaterialModule内のRazor Pagesアプリケーション。

URL: `/Material/MasterMaintenance`

## 用語集

- **MasterMaintenance_Page**: MaterialModule/Areas/Material/Pages/MasterMaintenance/Index に配置されたマスタメンテナンス画面
- **Tab**: タブ切り替えパラメータ。items / suppliers / purchase / packages / warehouses / usage2 / usage3
- **MItem**: 品目マスタエンティティ（m_items テーブル）
- **MSupplier**: 仕入先マスタエンティティ（m_suppliers テーブル）
- **MPurchaseCondition**: 購買条件エンティティ（m_purchase_conditions テーブル）
- **MPackageType**: 荷姿マスタエンティティ（m_package_types テーブル）
- **MWarehouse**: 倉庫マスタエンティティ（m_warehouses テーブル）
- **MUsage2Category**: 用途2マスタエンティティ（m_usage2_categories テーブル）
- **MUsage3Category**: 用途3マスタエンティティ（m_usage3_categories テーブル）
- **Item_Modal**: 品目の登録・編集を行うモーダルダイアログ（itemModal）。一覧テーブルとは独立したフォームで品目情報を入力する
- **LotSizeType**: ロットサイズ区分。lot_for_lot（ロットフォーロット）/ fixed（固定）/ eoq（経済的発注量）
- **LeadTimeDays**: 納期日数。lead_time_days と default_delivery_days を統一管理する値
- **ItemCreateRequest**: 品目モーダルからの登録・更新リクエストDTO
- **Usage1Name / Usage2Name / Usage3Name**: 用途1/2/3のFK（Usage1/Usage2/Usage3）から引いた用途名の表示値

## 要件

### 要件 1: タブ切り替えによるマスタ一覧表示

**ユーザーストーリー:** 資材管理者として、複数のマスタデータをタブで切り替えて一覧表示できることで、各マスタの内容を効率的に確認したい。

#### 受入基準

1. THE MasterMaintenance_Page SHALL display 7 tabs: 品目マスタ(items), 仕入先マスタ(suppliers), 購買条件(purchase), 荷姿マスタ(packages), 倉庫マスタ(warehouses), 用途2マスタ(usage2), 用途3マスタ(usage3)
2. WHEN no Tab parameter is specified, THE MasterMaintenance_Page SHALL display the 品目マスタ tab as the default view
3. WHEN a Tab parameter is specified, THE MasterMaintenance_Page SHALL display only the data for the selected tab
4. THE MasterMaintenance_Page SHALL load data lazily per tab (only the selected tab's data is queried)
5. THE 品目マスタ tab SHALL display only active items (IsActive=true) ordered by ItemCode ascending
6. THE 仕入先マスタ tab SHALL display only active suppliers (IsActive=true) ordered by SupplierCode ascending
7. THE 購買条件 tab SHALL display only active purchase conditions (IsActive=true) ordered by ItemCode ascending
8. THE 荷姿マスタ tab SHALL display all package types ordered by Id ascending
9. THE 倉庫マスタ tab SHALL display all warehouses ordered by WarehouseCode ascending
10. THE 用途2マスタ tab SHALL display usage2 categories ordered by SortOrder ascending
11. THE 用途3マスタ tab SHALL display usage3 categories ordered by SortOrder ascending

### 要件 2: 品目マスタ 一覧表示（表示専用）とモーダル編集

**ユーザーストーリー:** 資材管理者として、品目マスタの一覧を読み取り専用で確認し、登録・編集は専用のモーダルで行うことで、誤操作を防ぎながら品目情報をまとめて編集したい。

#### 受入基準

1. THE 品目マスタ tab SHALL display all columns as read-only text: 品目コード(item_code), 品目名(item_name), 安全在庫(safety_stock_qty), 発注点(stock_minimum_qty), 発注個数(order_unit_qty), 標準発注数量(default_order_qty), 納期(日)(lead_time_days), ロットタイプ(lot_size_type), 固定ロット数(fixed_lot_qty), 用途1(Usage1), 用途2(Usage2), 用途3(Usage3)
2. THE 品目マスタ tab SHALL NOT render any input or select editing controls within the list table rows
3. THE 品目マスタ tab SHALL display 用途1, 用途2, and 用途3 as their resolved category names (Usage1Name / Usage2Name / Usage3Name); WHEN the corresponding foreign key is null, THE MasterMaintenance_Page SHALL display "-" as placeholder
4. THE 品目マスタ tab SHALL display an "編集" button for each row as the only row-level action control
5. WHEN the user clicks the "編集" button for a row, THE MasterMaintenance_Page SHALL open Item_Modal populated with the selected item's current values
6. THE 品目マスタ tab SHALL display a "品目追加" button that opens Item_Modal with empty input fields for new item registration
7. THE MasterMaintenance_Page SHALL NOT render a row-level "保存" button in the 品目マスタ list table

### 要件 2A: 品目モーダルによる登録・編集

**ユーザーストーリー:** 資材管理者として、品目モーダルから品目の全項目を登録・編集できることで、一覧テーブルを直接操作せずに品目情報を管理したい。

#### 受入基準

1. WHEN the user opens Item_Modal for editing, THE MasterMaintenance_Page SHALL request the item detail via handler=ItemDetail (OnGetItemDetailAsync) and populate the modal fields with the returned values
2. WHEN the user saves a new item from Item_Modal, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=CreateItem (OnPostCreateItemAsync) with the modal field values
3. WHEN the user saves an existing item from Item_Modal, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=UpdateItem (OnPostUpdateItemAsync) with the modal field values and the item's RowVersion
4. THE Item_Modal save request SHALL include a RequestVerificationToken header for CSRF protection
5. THE Item_Modal save request SHALL use Content-Type: application/json
6. IF the specified item Id is not found during update, THEN THE handler SHALL return { success: false, message: "品目が見つかりません" }
7. WHEN saving succeeds, THE handler SHALL update the item's UpdatedAt timestamp to the current UTC time
8. THE Item_Modal SHALL provide 用途2(Usage2) and 用途3(Usage3) as dropdown selects sourced from the active usage2/usage3 master categories
9. THE Item_Modal SHALL provide ロットタイプ(LotSizeType) as a dropdown select with options: lot_for_lot, fixed, eoq

### 要件 3: 納期日数の統一管理

**ユーザーストーリー:** 資材管理者として、納期日数が一つの入力で管理されることで、lead_time_days と default_delivery_days の不整合を防ぎたい。

#### 受入基準

1. THE Item_Modal SHALL display a single "納期(日)" field representing both lead_time_days and default_delivery_days
2. WHEN saving an item via Item_Modal, THE MasterMaintenance_Page SHALL set both lead_time_days and default_delivery_days to the same value derived from the "納期(日)" input
3. THE 品目マスタ list table SHALL display a single "納期(日)" value per item

### 要件 4: AJAX保存とフィードバック

**ユーザーストーリー:** 資材管理者として、保存操作の結果が即座にフィードバックされることで、保存成功・失敗を確認しながら作業を進めたい。

#### 受入基準

1. WHEN an Item_Modal save request succeeds, THE MasterMaintenance_Page SHALL close Item_Modal and display a success message at the top of the page
2. WHEN an Item_Modal save request fails, THE MasterMaintenance_Page SHALL display the returned error message to the user
3. THE Item_Modal save request SHALL include a RequestVerificationToken header for CSRF protection
4. THE Item_Modal save request SHALL use Content-Type: application/json
5. IF the specified item Id is not found, THEN THE handler SHALL return { success: false, message: "品目が見つかりません" }
6. WHEN saving succeeds, THE handler SHALL update the item's UpdatedAt timestamp to the current UTC time

### 要件 5: 仕入先マスタ表示

**ユーザーストーリー:** 資材管理者として、仕入先マスタの情報を一覧で確認できることで、仕入先の連絡先や区分を把握したい。

#### 受入基準

1. THE 仕入先マスタ tab SHALL display the following columns: 仕入先コード, 仕入先名, 正式名称, TEL, FAX, 住所, GR区分
2. THE 仕入先マスタ tab SHALL be read-only (no edit functionality)
3. WHEN a field value is null, THE MasterMaintenance_Page SHALL display "-" as placeholder

### 要件 6: 購買条件表示

**ユーザーストーリー:** 資材管理者として、購買条件の情報を一覧で確認できることで、品目ごとの仕入先・搬入先・購買区分を把握したい。

#### 受入基準

1. THE 購買条件 tab SHALL display the following columns: 品目コード, 仕入先コード, 搬入先, メーカー, 購買区分, 有効
2. THE 購買条件 tab SHALL be read-only (no edit functionality)
3. THE 購買区分 column SHALL display: 1="在庫", 2="預託", other="-"
4. THE 有効 column SHALL display: true="○", false="×"
5. WHEN a field value is null, THE MasterMaintenance_Page SHALL display "-" as placeholder

### 要件 7: 荷姿マスタ表示

**ユーザーストーリー:** 資材管理者として、荷姿マスタの情報を一覧で確認できることで、登録済みの荷姿種別を把握したい。

#### 受入基準

1. THE 荷姿マスタ tab SHALL display the following columns: ID, 荷姿名
2. THE 荷姿マスタ tab SHALL be read-only (no edit functionality)

### 要件 8: 倉庫マスタ表示

**ユーザーストーリー:** 資材管理者として、倉庫マスタの情報を一覧で確認できることで、登録済みの倉庫を把握したい。

#### 受入基準

1. THE 倉庫マスタ tab SHALL display the following columns: 倉庫コード, 倉庫名
2. THE 倉庫マスタ tab SHALL be read-only (no edit functionality)

### 要件 9: 認可制御

**ユーザーストーリー:** システム管理者として、マスタメンテナンスページへのアクセスが権限のあるユーザーに限定されることで、不正なマスタ変更を防止したい。

#### 受入基準

1. THE MasterMaintenance_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy

### 要件 10: 排他制御 — 楽観的ロック（2026/05/27実装済み）

**ユーザーストーリー:** 資材管理者として、同時編集時にデータが上書きされないことで、データの整合性が保たれる。

#### 受入基準

1. WHEN saving an item via Item_Modal, THE MasterMaintenance_Page SHALL apply optimistic locking using RowVersion
2. THE MasterMaintenance_Page SHALL return RowVersion as a Base64 string (string?) to the client and send it on the next save request
3. IF an optimistic locking conflict is detected, THEN THE MasterMaintenance_Page SHALL display the message "他のユーザーが先に更新しました。画面を再読み込みしてください。"

### 要件 11: AJAX保存改善（2026/05/27実装済み）

**ユーザーストーリー:** 資材管理者として、AJAX保存が確実に動作することで、マスタ更新作業を安心して行える。

#### 受入基準

1. THE MasterMaintenance_Page SHALL AJAX保存時に `@Url.Page(...)` による絶対パスURLを使用する
2. THE MasterMaintenance_Page SHALL `[IgnoreAntiforgeryToken]` をクラスレベルに設定する
3. THE MasterMaintenance_Page SHALL `@Html.AntiForgeryToken()` をページに配置する
4. WHEN 保存が成功したとき, THE MasterMaintenance_Page SHALL ページ上部に成功メッセージを表示する

### 要件 12: 名称変更（2026/05/27実装済み）

**ユーザーストーリー:** 資材管理者として、フィールド名が業務用語と一致していることで、操作対象を正確に把握できる。

#### 受入基準

1. THE MasterMaintenance_Page SHALL 「発注単位」の表示名称を「発注個数」に変更する
2. THE Item_Modal SHALL 「発注個数」入力フィールドの step を整数（1）に設定する

### 要件 13: UI統一（2026/05/27実装済み）

**ユーザーストーリー:** 資材管理者として、統一されたUI表示を得ることで、操作に迷わず効率的に業務を遂行できる。

#### 受入基準

1. THE MasterMaintenance_Page SHALL ページ先頭に `<partial name="_MaterialStyles" />` を配置する
2. THE MasterMaintenance_Page SHALL コンテナに `material-page` クラスを適用する
3. THE MasterMaintenance_Page SHALL タイトルを `<h5 class="mb-2">` で表示する
4. THE MasterMaintenance_Page SHALL テーブルのフォントサイズを 0.75rem で統一する

### 要件 14: 用途2/用途3マスタのインライン CRUD

**ユーザーストーリー:** 資材管理者として、用途2・用途3マスタを画面上で追加・編集・削除できることで、品目モーダルの選択肢を直接管理したい。

#### 受入基準

1. THE 用途2マスタ tab SHALL display the following columns: ID, 用途2名, 並び順, 操作
2. THE 用途3マスタ tab SHALL display the following columns: ID, 用途3名, 並び順, 操作
3. WHEN the user saves a usage2 category, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=CreateUsage2 (OnPostCreateUsage2Async) for new records or handler=UpdateUsage2 (OnPostUpdateUsage2Async) for existing records
4. WHEN the user saves a usage3 category, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=CreateUsage3 (OnPostCreateUsage3Async) for new records or handler=UpdateUsage3 (OnPostUpdateUsage3Async) for existing records
5. WHEN the user deletes a usage2 category, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=DeleteUsage2 (OnPostDeleteUsage2Async)
6. WHEN the user deletes a usage3 category, THE MasterMaintenance_Page SHALL send an AJAX POST request to handler=DeleteUsage3 (OnPostDeleteUsage3Async)
7. IF a usage2 category is referenced by any item (Usage2 FK), THEN THE MasterMaintenance_Page SHALL reject the deletion with the message "この用途2は品目で使用中のため削除できません。"
8. IF a usage3 category is referenced by any item (Usage3 FK), THEN THE MasterMaintenance_Page SHALL reject the deletion with the message "この用途3は品目で使用中のため削除できません。"

### 要件 15: 品目インライン編集の廃止（モーダル集約への移行）

**ユーザーストーリー:** 資材管理者として、品目の編集経路がモーダルに一本化されることで、一覧テーブル上の入力欄や行内保存ボタンによる誤操作を避けたい。

#### 受入基準

1. THE 品目マスタ list table SHALL NOT contain inline input or select controls for editing item fields
2. THE 品目マスタ list table SHALL NOT contain a row-level "保存" (inline save) button
3. THE MasterMaintenance_Page SHALL route all item registration and editing through Item_Modal (handler=CreateItem / handler=UpdateItem)
4. WHERE the legacy inline save handler (handler=SaveItem / OnPostSaveItemAsync) remains present for backward compatibility, THE 品目マスタ list table SHALL NOT invoke it from the UI
