# 要件定義書: 発注管理ページ

## はじめに

発注管理モジュール（Orders）の3画面（発注エントリ・発注確認・発注検索）に関する要件定義。MaterialModule内のRazor Pagesアプリケーションとして実装され、品目の発注から注文確定までのワークフローを管理する。

## 用語集

- **Orders/Create**: 発注エントリ画面。品目を検索し、発注エントリを作成・一括登録する
- **Orders/Confirm**: 発注確認画面。回答待ち(status=30)と注文確定(status=50)の2ビューを切り替え、確認・取消操作を行う
- **Orders/Search**: 発注検索画面。全ステータスの発注を横断検索し、PDF/Excel出力を行う
- **TOrder**: 発注データエンティティ（t_orders テーブル）
- **OrderStatus**: 発注ステータス値。10=エントリ、15=差戻し、20=承認待ち、30=回答待ち、40=発注済み、50=注文確定、60=入庫済み、70=出庫済み
- **ItemSelectDto**: 品目検索結果DTO（品目ID、品目コード、品目名、デフォルト発注数量、デフォルト納期日数等）
- **PurchaseConditionDto**: 購買条件DTO（送付先情報）
- **OrderListDto**: 発注一覧表示用DTO
- **OrderCreateDto**: 発注エントリ作成用DTO（品目ID、数量、納期日、倉庫コード、出力種別、備考）
- **営業日計算**: カレンダーマスタに基づき休日を除外した日数計算
- **デフォルト発注数量**: 品目マスタに設定された標準発注数量（DefaultOrderQty）
- **デフォルト納期日数**: 品目マスタに設定された標準納期日数（DefaultDeliveryDays）

## 要件

### 要件 1: 品目検索（オートコンプリート）

**ユーザーストーリー:** 発注担当者として、品目コードまたは品目名の一部を入力するだけで候補が表示されることで、素早く正確に品目を選択したい。

#### 受入基準

1. WHEN a user types a keyword in the item search field, THE Orders/Create page SHALL send an AJAX request and display up to 20 matching item suggestions
2. IF the keyword is empty or whitespace, THEN THE Orders/Create page SHALL not send a search request and SHALL display no suggestions
3. WHEN a user selects an item from the suggestions, THE Orders/Create page SHALL populate the item ID and display the item name, item code, and related details
4. WHEN an item is selected, THE Orders/Create page SHALL retrieve and display the purchase condition (destination) for that item
5. WHEN an item with DefaultOrderQty is selected, THE Orders/Create page SHALL auto-fill the order quantity field with the default value
6. WHEN an item with DefaultDeliveryDays is selected, THE Orders/Create page SHALL calculate the delivery date using business day calculation from today and auto-fill the delivery date field

### 要件 2: 発注エントリ作成

**ユーザーストーリー:** 発注担当者として、品目・数量・納期日・倉庫を指定してエントリを作成し、後でまとめて発注登録したい。

#### 受入基準

1. THE Orders/Create page SHALL provide input fields for: item (required), order quantity (required, > 0), delivery date, warehouse, output type, and remarks
2. WHEN a user submits a valid entry, THE Orders/Create page SHALL create a TOrder record with OrderStatus=10 (エントリ) and associate it with the logged-in user
3. IF the item is not selected (ItemId <= 0), THEN THE Orders/Create page SHALL display the error message "品目を選択してください。"
4. IF the order quantity is 0 or negative, THEN THE Orders/Create page SHALL display the error message "数量は0より大きい値を指定してください。"
5. WHEN an entry is successfully added and the item has no DefaultOrderQty set, THE Orders/Create page SHALL automatically save the entered quantity as the new DefaultOrderQty
6. WHEN a user checks "update default" and submits, THE Orders/Create page SHALL update the item's DefaultOrderQty with the entered quantity
7. WHEN an entry is successfully added, THE Orders/Create page SHALL clear the input form and display a success message

### 要件 3: エントリ一覧表示

**ユーザーストーリー:** 発注担当者として、自分が作成したエントリの一覧を確認し、不要なものを削除してから一括登録したい。

#### 受入基準

1. THE Orders/Create page SHALL display a paginated list of the logged-in user's entries with OrderStatus=10
2. THE Orders/Create page SHALL support page sizes of 10, 20, 30, or 50 items per page, persisted per user
3. THE Orders/Create page SHALL support sorting by: created date, delivery date, quantity, and item name
4. WHEN a user clicks the remove button for an entry, THE Orders/Create page SHALL delete that TOrder record
5. THE Orders/Create page SHALL display quantity calculation (OrderQty × UnitContentQty) when applicable

### 要件 4: 一括発注登録

**ユーザーストーリー:** 発注担当者として、選択したエントリをまとめて発注登録し、承認プロセスに進めたい。

#### 受入基準

1. WHEN a user selects one or more entries and clicks submit, THE Orders/Create page SHALL update the selected entries' OrderStatus from 10 to 20 (承認待ち)
2. WHEN the submission succeeds, THE Orders/Create page SHALL display the message "{count} 件の発注を確定しました。"
3. IF no entries are selected, THEN THE Orders/Create page SHALL display the error message "発注確定するエントリを選択してください。"
4. IF a submission fails due to invalid state, THEN THE Orders/Create page SHALL display the error message from the exception

### 要件 5: 発注確認 — ビュー切替

**ユーザーストーリー:** 発注確認担当者として、「回答待ち」と「注文確定」の発注を切り替えて表示し、それぞれの状態に応じた操作を行いたい。

#### 受入基準

1. THE Orders/Confirm page SHALL provide two view modes: "before" (回答待ち, status=30) and "after" (注文確定, status=50)
2. WHEN the "before" view is selected, THE Orders/Confirm page SHALL display only orders with OrderStatus=30
3. WHEN the "after" view is selected, THE Orders/Confirm page SHALL display only orders with OrderStatus=50
4. THE Orders/Confirm page SHALL default the user filter to the logged-in user
5. THE Orders/Confirm page SHALL provide a user dropdown populated from distinct users who have orders with status=30

### 要件 6: 発注確認 — 検索フィルタ

**ユーザーストーリー:** 発注確認担当者として、発注番号・品目・日付・送付先で絞り込むことで、対象の発注を素早く見つけたい。

#### 受入基準

1. THE Orders/Confirm page SHALL provide search filters for: order number, item code, item name, date range (delivery date), destination, and user
2. WHEN filters are applied, THE Orders/Confirm page SHALL display only orders matching all specified conditions (AND logic)
3. WHEN the user filter is set to "all", THE Orders/Confirm page SHALL display orders from all users
4. THE Orders/Confirm page SHALL support pagination with page sizes of 10, 20, 30, or 50
5. THE Orders/Confirm page SHALL support sorting by: order number, item code, item name, quantity, order date, delivery date, and destination

### 要件 7: 発注確認 — 個別/一括確定

**ユーザーストーリー:** 発注確認担当者として、回答待ちの発注を個別または一括で注文確定に進めたい。

#### 受入基準

1. WHEN a user clicks the confirm button for a single order, THE Orders/Confirm page SHALL update that order's status from 30 to 50 (注文確定)
2. WHEN individual confirmation succeeds, THE Orders/Confirm page SHALL display "{OrderNo} を注文確定しました。"
3. WHEN a user selects multiple orders and clicks bulk confirm, THE Orders/Confirm page SHALL update all selected orders' status from 30 to 50
4. WHEN bulk confirmation succeeds, THE Orders/Confirm page SHALL display "{count} 件を注文確定しました。"
5. IF no orders are selected for bulk confirm, THEN THE Orders/Confirm page SHALL display "注文確定する発注を選択してください。"
6. IF the target order does not exist or status is not 30, THEN THE Orders/Confirm page SHALL display an error message

### 要件 8: 発注確認 — 確定取消

**ユーザーストーリー:** 発注確認担当者として、誤って確定した発注を回答待ちに戻すことで、修正を可能にしたい。

#### 受入基準

1. WHEN a user clicks the unconfirm button for an order with status=50, THE Orders/Confirm page SHALL update that order's status from 50 to 30 (回答待ち)
2. WHEN unconfirm succeeds, THE Orders/Confirm page SHALL display "{OrderNo} を未確定に戻しました。"
3. IF the target order does not exist or status is not 50, THEN THE Orders/Confirm page SHALL display an error message

### 要件 9: 発注確認 — インライン編集

**ユーザーストーリー:** 発注確認担当者として、回答待ちの発注の数量や納期を画面上で直接修正したい。

#### 受入基準

1. WHEN an order has status=30, THE Orders/Confirm page SHALL allow inline editing of order quantity and delivery date
2. WHEN a user submits an inline edit, THE Orders/Confirm page SHALL update the order's OrderQty, UnitContentQty, TotalQty (OrderQty × UnitContentQty), Amount (UnitPrice × TotalQty), and DeliveryDate
3. WHEN the edit succeeds, THE Orders/Confirm page SHALL display "{OrderNo} を更新しました。"
4. IF the target order does not exist or status is not 30, THEN THE Orders/Confirm page SHALL display "対象の発注が見つからないか、編集できない状態です。"

### 要件 10: 発注検索 — 全ステータス横断検索

**ユーザーストーリー:** 管理者として、全ステータスの発注を横断的に検索し、発注状況を把握したい。

#### 受入基準

1. THE Orders/Search page SHALL provide search filters for: order number, item code, item name, status, order date range, delivery date range, user, destination, supplier, and warehouse
2. WHEN filters are applied, THE Orders/Search page SHALL display only orders matching all specified conditions (AND logic)
3. THE Orders/Search page SHALL provide a status dropdown with options: 全て, エントリ(10), 差戻し(15), 承認待ち(20), 回答待ち(30), 発注済み(40), 注文確定(50), 入庫済み(60), 出庫済み(70)
4. THE Orders/Search page SHALL support pagination with page sizes of 10, 20, 30, or 50
5. THE Orders/Search page SHALL sort results by order date descending, then by ID descending (default)

### 要件 11: 発注検索 — PDF出力

**ユーザーストーリー:** 発注担当者として、個別の発注書をPDFでダウンロードし、印刷や送付に使用したい。

#### 受入基準

1. WHEN a user clicks the PDF download button for an order, THE Orders/Search page SHALL generate and download a PDF file for that order
2. THE Orders/Search page SHALL return the PDF with content-type "application/pdf"

### 要件 12: 発注検索 — Excel出力

**ユーザーストーリー:** 管理者として、検索結果をExcelファイルとしてエクスポートし、集計や報告に活用したい。

#### 受入基準

1. WHEN a user clicks the Excel export button, THE Orders/Search page SHALL generate an Excel file containing all orders matching the current search conditions (not limited to current page)
2. THE Orders/Search page SHALL include the following columns in the Excel: No, 発注番号, ステータス, 種別, 品目コード, 品目名, 数量, 単価, 金額(千円), 発注日, 納期, 送付先, 倉庫名, 発注者, 承認日時, 承認者
3. THE Orders/Search page SHALL format the Excel with bold headers and light gray background on the header row
4. THE Orders/Search page SHALL name the download file "発注データ_{yyyyMMdd}.xlsx"

### 要件 13: 認可制御

**ユーザーストーリー:** システム管理者として、権限のないユーザーが発注ページにアクセスできないようにしたい。

#### 受入基準

1. THE Orders/Create, Orders/Confirm, and Orders/Search pages SHALL require authentication
2. THE Orders pages SHALL enforce the "DbPermissionCheck" authorization policy
3. IF a user is not authenticated or not authorized, THEN THE system SHALL deny access to the Orders pages

### 要件 14: ページサイズ保持

**ユーザーストーリー:** 発注担当者として、各画面で設定したページサイズが次回アクセス時にも維持されることで、毎回設定し直す手間を省きたい。

#### 受入基準

1. WHEN a user changes the page size on any Orders page, THE system SHALL persist the selected page size per user per page (Orders_Create, Orders_Confirm, Orders_Search)
2. WHEN a user revisits an Orders page, THE system SHALL restore the previously selected page size
3. THE system SHALL only accept page sizes of 10, 20, 30, or 50

### 要件 15: 操作者トレーサビリティ — 確定者名（2026/05/27実装済み）

**ユーザーストーリー:** 管理者として、発注確定の実行者名が記録・表示されることで、誰がいつ確定したかを追跡できる。

#### 受入基準

1. WHEN 発注が確定されたとき, THE Orders/Confirm SHALL 確定者ID（confirmed_by）、確定者名（confirmed_by_name）、確定日時（confirmed_at）を t_orders に保存する
2. WHEN 発注確定が取り消されたとき, THE Orders/Confirm SHALL confirmed_by, confirmed_by_name, confirmed_at をクリアする
3. THE Orders/Confirm SHALL 「確定者」列を納期確定リスト（StatusView="after"）のみに表示する（回答待ちリストでは非表示）
4. THE Orders/Confirm SHALL 操作者名としてユーザーの LastName を使用する
5. THE Orders/Confirm SHALL 発注者ヘッダーをソートリンクとして表示する

### 要件 16: UI統一 — 用語・フォント（2026/05/27実装済み）

**ユーザーストーリー:** 発注担当者として、統一されたUI表示を得ることで、操作に迷わず効率的に業務を遂行できる。

#### 受入基準

1. THE Orders/Confirm SHALL 「発注日」の表示名称を「起票日」に統一する
2. THE Orders/Search SHALL 「発注日」の表示名称を「起票日」に統一する
3. THE Orders/Confirm SHALL 「一括確定」ボタンに `text-nowrap` クラスを適用する
4. THE Orders pages SHALL ページ先頭に `<partial name="_MaterialStyles" />` を配置する
5. THE Orders pages SHALL コンテナに `material-page` クラスを適用する
6. THE Orders pages SHALL タイトルを `<h5 class="mb-2">` で表示する
7. THE Orders pages SHALL テーブルのフォントサイズを 0.75rem で統一する
