# 要件定義書

## はじめに

原材料工場入請求登録ページ（Dispatches/Index）の機能仕様。ユーザーが原材料の出庫請求エントリを作成し、一括登録（ステータス遷移＋在庫減算＋PDF生成）を行うためのRazor Pages画面。MaterialModule内に配置される。

## 用語集

- **Dispatches_Page**: MaterialModule/Areas/Material/Pages/Dispatches/Index に配置された原材料工場入請求登録画面
- **TDispatch**: 出庫請求データを格納するエンティティ（t_dispatches テーブル）
- **Status**: TDispatchのステータス値。0=未登録、1=搬入前
- **未登録ビュー（pending）**: Status=0のエントリを表示するビュー。エントリの追加・削除・登録が可能
- **搬入前ビュー（pre-delivery）**: Status=1のエントリを表示するビュー。戻し操作が可能（SuperUserのみ）
- **MItem**: 品目マスタエンティティ
- **MDeliveryLocation**: 搬入場所マスタエンティティ（section_idによるフィルタ対応）
- **IStockService**: 在庫管理サービスインターフェース
- **IMasterService**: マスタデータ検索サービスインターフェース
- **SharedCore.IUserRepository**: ユーザー所属情報取得インターフェース
- **QuestPDF**: PDF生成ライブラリ（Community License）
- **SuperUser**: 戻し操作が許可されたロール

## 要件

### 要件 1: ビュー切り替え

**ユーザーストーリー:** 請求担当者として、未登録エントリと搬入前エントリを切り替えて表示できることで、作業状態に応じた一覧を確認したい。

#### 受入基準

1. THE Dispatches_Page SHALL display two view toggle buttons: "未登録" and "搬入前"
2. WHEN the "未登録" button is selected, THE Dispatches_Page SHALL display only TDispatch records with Status=0 for the current user, ordered by CreatedAt ascending
3. WHEN the "搬入前" button is selected, THE Dispatches_Page SHALL display only TDispatch records with Status=1 for the current user, ordered by DispatchDate descending then ItemName ascending
4. THE Dispatches_Page SHALL default to the "未登録" view when no StatusView parameter is specified

### 要件 2: 品目検索（AJAXオートコンプリート）

**ユーザーストーリー:** 請求担当者として、品目コードまたは品名の一部を入力するだけで候補が表示されることで、素早く正確に品目を選択したい。

#### 受入基準

1. WHEN the user types in the item input field, THE Dispatches_Page SHALL send an AJAX request to the SearchItem handler after a 300ms debounce
2. THE SearchItem handler SHALL return up to 20 matching items based on keyword (code or name partial match)
3. THE Dispatches_Page SHALL display search results as a dropdown suggestion list showing "品目コード - 品名"
4. WHEN the user selects an item from the suggestion list, THE Dispatches_Page SHALL populate the hidden item ID field and display the item detail (code + name)
5. WHEN an item is selected, THE Dispatches_Page SHALL display the item's ContentQty (入目) value
6. THE Dispatches_Page SHALL support keyboard navigation (ArrowUp, ArrowDown, Enter, Escape) in the suggestion list

### 要件 3: 在庫数量表示（AJAX）

**ユーザーストーリー:** 請求担当者として、品目選択時に現在の在庫数を確認できることで、適切な個数を入力したい。

#### 受入基準

1. WHEN an item is selected, THE Dispatches_Page SHALL send an AJAX request to the Stock handler with the item ID
2. THE Stock handler SHALL return stock information for all warehouses associated with the item
3. THE Dispatches_Page SHALL display the total stock count (sum of all warehouses) below the quantity input field

### 要件 4: エントリ作成

**ユーザーストーリー:** 請求担当者として、品目・個数・搬入日・搬入場所・備考を指定してエントリを作成できることで、工場入請求の準備を行いたい。

#### 受入基準

1. THE Dispatches_Page SHALL provide input fields for: 品目（必須）、個数（必須）、搬入日、搬入場所、備考
2. WHEN the user submits the Add form with valid data, THE Dispatches_Page SHALL create a new TDispatch record with Status=0
3. THE new TDispatch record SHALL include: DispatchDate (default=today), ItemId, DispatchQty, WarehouseCode (from item), WarehouseName (from item), Destination=搬入場所, DeliveryLocation=搬入場所, DepartmentName (from user section), CostCenter (from user section), Remarks, UserId=login name
4. IF the item ID is invalid or not found, THEN THE Dispatches_Page SHALL display the error message "品目が見つかりません。"
5. IF the quantity is 0, THEN THE Dispatches_Page SHALL display the error message "個数を入力してください。"
6. IF no delivery location is selected, THEN THE Dispatches_Page SHALL display the error message "搬入場所を選択してください。"
7. WHEN entry creation succeeds, THE Dispatches_Page SHALL display a success message "{品目コード} {品名} を追加しました。" and redirect to the same view

### 要件 5: 搬入場所ドロップダウン（セクションフィルタ）

**ユーザーストーリー:** 請求担当者として、自分の所属部門に関連する搬入場所のみが表示されることで、誤った場所を選択するリスクを減らしたい。

#### 受入基準

1. THE Dispatches_Page SHALL display a delivery location dropdown populated from MDeliveryLocation records
2. THE Dispatches_Page SHALL filter delivery locations by the user's section_id (from SharedCore.IUserRepository)
3. THE Dispatches_Page SHALL also include delivery locations where section_id is NULL or empty (shared locations)
4. THE delivery locations SHALL be ordered by SortId ascending
5. THE delivery location dropdown SHALL display distinct LocationName values only

### 要件 6: ユーザー所属情報表示

**ユーザーストーリー:** 請求担当者として、自分の氏名・部署名・内線番号が画面上部に表示されることで、正しいアカウントで操作していることを確認したい。

#### 受入基準

1. THE Dispatches_Page SHALL display the user's full name, department name, and extension number in the header area
2. THE user information SHALL be retrieved from SharedCore.IUserRepository using the authenticated user's IdentityId
3. IF the extension number is empty, THEN THE Dispatches_Page SHALL not display the extension number section

### 要件 7: エントリ削除

**ユーザーストーリー:** 請求担当者として、誤って追加したエントリを削除できることで、正確な請求リストを維持したい。

#### 受入基準

1. WHEN in the "未登録" view, THE Dispatches_Page SHALL allow the user to select one or more entries via checkboxes
2. WHEN the user clicks the "削除" button with entries selected, THE Dispatches_Page SHALL show a confirmation dialog "選択したエントリを削除しますか？"
3. WHEN deletion is confirmed, THE Dispatches_Page SHALL remove the selected TDispatch records (Status=0, current user only)
4. WHEN deletion succeeds, THE Dispatches_Page SHALL display the success message "{count} 件削除しました。"
5. THE "削除" button SHALL be disabled when no entries are selected

### 要件 8: 一括登録（ステータス遷移＋在庫減算）

**ユーザーストーリー:** 請求担当者として、エントリを一括登録することで、在庫を減算し搬入前ステータスに移行させたい。

#### 受入基準

1. WHEN in the "未登録" view, THE Dispatches_Page SHALL display a "登録" button
2. WHEN the user clicks "登録" with entries selected, THE Dispatches_Page SHALL show a confirmation dialog "選択した {count} 件を登録しますか？"
3. WHEN no entries are explicitly selected, THE Dispatches_Page SHALL target all Status=0 entries for the current user
4. WHEN registration is confirmed, THE Dispatches_Page SHALL update each target entry: Status 0→1, SubmittedAt=current UTC time, UpdatedAt=current UTC time
5. WHEN registration is confirmed, THE Dispatches_Page SHALL call IStockService.DecrementStockAsync for each entry using: ItemId, ItemCode, WarehouseCode, UnitContentQty (from Item.ContentQty), DispatchQty
6. IF no entries exist to register, THEN THE Dispatches_Page SHALL display the error message "登録するエントリがありません。"
7. WHEN registration succeeds without PDF output, THE Dispatches_Page SHALL display the success message "{count} 件を登録しました。"

### 要件 9: PDF生成（原材料工場入請求伝票）

**ユーザーストーリー:** 請求担当者として、登録時にPDF伝票を自動生成・ダウンロードできることで、紙ベースの請求フローに対応したい。

#### 受入基準

1. THE Dispatches_Page SHALL display a "PDF出力" checkbox (default: checked) next to the "登録" button
2. WHEN "PDF出力" is checked and registration succeeds, THE Dispatches_Page SHALL generate a PDF file and trigger a download
3. THE PDF SHALL be titled "原材料工場入請求伝票" with subtitle "（工場入作業依頼書）"
4. THE PDF SHALL group entries by DispatchDate, with one page per date group
5. THE PDF header SHALL include: 部署名, 原価センター, 搬入年月日/回, 請求者名, 内線番号
6. THE PDF table SHALL include columns: 品名, 品目コード, 入目, 個数, 倉庫, 備考, 搬入場所
7. THE PDF SHALL use A4 page size with QuestPDF (Community License) and "Yu Gothic" font
8. THE PDF filename SHALL follow the pattern "工場入請求_{yyyyMMdd}.pdf"
9. WHEN "PDF出力" is unchecked, THE Dispatches_Page SHALL skip PDF generation and only perform the registration

### 要件 10: 戻し操作（SuperUserのみ）

**ユーザーストーリー:** 管理者（SuperUser）として、誤って登録されたエントリを未登録状態に戻せることで、操作ミスを修正したい。

#### 受入基準

1. THE Recover handler SHALL only be accessible to users with the "SuperUser" role
2. IF a non-SuperUser attempts the Recover action, THEN THE Dispatches_Page SHALL return a 403 Forbidden response
3. WHEN the Recover action is executed on selected entries, THE Dispatches_Page SHALL update each target entry: Status 1→0, SubmittedAt=null, UpdatedAt=current UTC time
4. WHEN recovery succeeds, THE Dispatches_Page SHALL display the success message "{count} 件を未登録に戻しました。"
5. THE Recover action SHALL only target entries with Status=1 belonging to the current user

### 要件 11: エントリリスト表示

**ユーザーストーリー:** 請求担当者として、エントリの一覧を見やすい表形式で確認できることで、登録内容を把握したい。

#### 受入基準

1. THE Dispatches_Page SHALL display entries in a table with columns: No, 搬入日, 品目名, 品目コード, 入目, 個数, 倉庫, 備考, 搬入場所
2. WHEN in the "未登録" view, THE Dispatches_Page SHALL display checkboxes for entry selection
3. THE Dispatches_Page SHALL display a "全選択/解除" checkbox in the table header
4. THE Dispatches_Page SHALL support row click to toggle the checkbox selection
5. THE Dispatches_Page SHALL display the total entry count in the card header "エントリリスト（N 件）"
6. THE Dispatches_Page SHALL support client-side sorting by dispatch date column

### 要件 12: 認可

**ユーザーストーリー:** システム管理者として、権限のないユーザーがこのページにアクセスできないことで、セキュリティを確保したい。

#### 受入基準

1. THE Dispatches_Page SHALL require authentication via the "DbPermissionCheck" authorization policy
2. IF an unauthenticated user accesses the page, THEN THE system SHALL redirect to the login page
