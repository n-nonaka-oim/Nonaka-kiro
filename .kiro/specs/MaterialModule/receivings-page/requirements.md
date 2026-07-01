# 要件定義書

## はじめに

入庫管理ページ（Receivings/Index）の機能仕様。注文確定（ステータス50）および入庫済み（ステータス60）の発注データを一覧表示し、入庫処理・一括入庫・入庫取消・インライン編集・PDF出力を提供する。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **Receivings_Page**: MaterialModule/Areas/Material/Pages/Receivings/Index に配置された入庫管理画面
- **TOrder**: 発注テーブルエンティティ（t_orders）。OrderStatusフィールドでステータス管理
- **TReceiving**: 入庫レコードエンティティ（t_receivings）。入庫処理時に作成、取消時に削除
- **OrderStatus 50**: 注文確定（入庫待ち状態）
- **OrderStatus 60**: 入庫済み
- **TStock**: 在庫テーブルエンティティ。入庫時にIncrementStockAsyncで在庫増加
- **OrderStatusHelper**: 楽観的ロック付きステータス変更ヘルパー
- **IStockService**: 在庫増減を管理するサービスインターフェース
- **IMasterService**: 倉庫マスタ等を取得するサービスインターフェース
- **IUserPreferenceService**: ユーザーごとのページサイズ設定を管理するサービス
- **QuestPDF**: PDF生成ライブラリ（入庫伝票出力に使用）

## 要件

### 要件 1: 入庫対象一覧表示

**ユーザーストーリー:** 倉庫担当者として、注文確定および入庫済みの発注を一覧で確認できることで、入庫作業の進捗を把握したい。

#### 受入基準

1. THE Receivings_Page SHALL display orders with OrderStatus 50 (注文確定) and OrderStatus 60 (入庫済み) in a combined list
2. THE Receivings_Page SHALL display the following columns: 発注番号, 品番, 品目, 個数, 納入先, 発注日, 納入日, 入庫日, 倉庫
3. THE Receivings_Page SHALL support pagination with configurable page sizes of 10, 20, 30, or 50 records per page
4. THE Receivings_Page SHALL persist the user's page size preference per user via IUserPreferenceService
5. THE Receivings_Page SHALL default the page size to the user's previously saved preference

### 要件 2: ソート機能

**ユーザーストーリー:** 倉庫担当者として、一覧を任意の列で並べ替えられることで、必要な発注を素早く見つけたい。

#### 受入基準

1. THE Receivings_Page SHALL support sorting by the following columns: orderno, itemcode, itemname, qty, dest, date, delivery, received, warehouse
2. THE Receivings_Page SHALL default to sorting by delivery date (ascending), then warehouse name, then item name
3. WHEN a user clicks a column header, THE Receivings_Page SHALL toggle the sort direction (ascending/descending)
4. WHEN sorting by delivery, THE Receivings_Page SHALL apply secondary sort by warehouse name and tertiary sort by item name

### 要件 3: フィルタ機能

**ユーザーストーリー:** 倉庫担当者として、日付範囲・倉庫・ステータスで絞り込めることで、対象の入庫作業に集中したい。

#### 受入基準

1. THE Receivings_Page SHALL provide a delivery date range filter (DateFrom, DateTo) defaulting to today's date
2. THE Receivings_Page SHALL provide a received date range filter (ReceivedDateFrom, ReceivedDateTo)
3. THE Receivings_Page SHALL provide a warehouse dropdown filter populated from active warehouses via IMasterService
4. THE Receivings_Page SHALL provide a status filter to show only status 50, only status 60, or both (default: both)
5. WHEN no warehouse is selected, THE Receivings_Page SHALL display records from all warehouses
6. WHEN filters are applied, THE Receivings_Page SHALL preserve filter values across pagination and sorting operations
7. THE Receivings_Page SHALL filter delivery dates using DeliveryDate >= DateFrom AND DeliveryDate <= DateTo
8. THE Receivings_Page SHALL filter received dates using ReceivedDate >= ReceivedDateFrom AND ReceivedDate <= ReceivedDateTo

### 要件 4: 個別入庫処理

**ユーザーストーリー:** 倉庫担当者として、個別の発注に対して入庫処理を実行できることで、到着した資材を正確に記録したい。

#### 受入基準

1. WHEN a record has OrderStatus 50, THE Receivings_Page SHALL display a "入庫" button in the action column
2. WHEN a user clicks the "入庫" button, THE Receivings_Page SHALL update the TOrder record by setting OrderStatus to 60 and OrderStatusText to "入庫済み"
3. WHEN the receive is executed, THE Receivings_Page SHALL set ReceivedDate to today's date IF ReceivedDate is not already set
4. WHEN the receive is executed, THE Receivings_Page SHALL create a TReceiving record with OrderId, ReceivedDate (today), ReceivedQty (= OrderQty), WarehouseCode, WarehouseName, and UserId
5. WHEN the receive is executed, THE Receivings_Page SHALL call IStockService.IncrementStockAsync to increase stock by the order quantity
6. WHEN the receive succeeds, THE Receivings_Page SHALL display the success message "{OrderNo} を入庫しました。"
7. THE Receivings_Page SHALL use OrderStatusHelper.UpdateWithLockAsync with expectedStatus=50 to ensure optimistic locking

### 要件 5: 一括入庫処理

**ユーザーストーリー:** 倉庫担当者として、複数の発注をまとめて入庫処理できることで、大量入荷時の作業効率を上げたい。

#### 受入基準

1. THE Receivings_Page SHALL provide checkboxes for selecting multiple orders with OrderStatus 50
2. THE Receivings_Page SHALL provide a "一括入庫" button to process all selected orders
3. IF no orders are selected, THEN THE Receivings_Page SHALL display the error message "入庫する発注を選択してください。"
4. WHEN bulk receive is executed, THE Receivings_Page SHALL update each selected order's status from 50 to 60 using OrderStatusHelper.BulkUpdateWithLockAsync
5. WHEN bulk receive is executed, THE Receivings_Page SHALL create TReceiving records and increment stock for each successfully updated order
6. WHEN bulk receive succeeds, THE Receivings_Page SHALL display the success message "{count} 件を入庫しました。"

### 要件 6: 入庫取消（未入庫に戻す）

**ユーザーストーリー:** 倉庫担当者として、誤って入庫処理した発注を元に戻せることで、操作ミスを修正したい。

#### 受入基準

1. WHEN a record has OrderStatus 60, THE Receivings_Page SHALL display a "戻す" button in the action column
2. WHEN a user clicks the "戻す" button, THE Receivings_Page SHALL update the TOrder record by setting OrderStatus to 50, OrderStatusText to "注文確定", and ReceivedDate to null
3. WHEN the unreceive is executed, THE Receivings_Page SHALL delete all TReceiving records associated with the order
4. WHEN the unreceive succeeds, THE Receivings_Page SHALL display the success message "未入庫に戻しました。"
5. THE Receivings_Page SHALL use OrderStatusHelper.UpdateWithLockAsync with expectedStatus=60 to ensure optimistic locking
6. IF the target order does not exist or OrderStatus is not 60, THEN THE Receivings_Page SHALL display an appropriate error message

### 要件 7: インライン編集

**ユーザーストーリー:** 倉庫担当者として、一覧画面上で個数・ロットNo・備考・入庫日を直接編集できることで、画面遷移なく情報を更新したい。

#### 受入基準

1. THE Receivings_Page SHALL allow inline editing of the following fields: 個数 (orderQty), ロットNo (lotNo), 備考 (remarks), 入庫日 (receivedDate)
2. THE Receivings_Page SHALL allow editing for records with OrderStatus 50 or 60
3. WHEN a record has OrderStatus 50, THE Receivings_Page SHALL NOT display the receivedDate edit field
4. WHEN a record has OrderStatus 60, THE Receivings_Page SHALL display the receivedDate edit field
5. WHEN the order quantity is changed, THE Receivings_Page SHALL recalculate TotalQty (= OrderQty × UnitContentQty) and Amount (= UnitPrice × TotalQty)
6. WHEN the order quantity is changed, THE Receivings_Page SHALL append a change note "個数変更: {旧値}→{新値}" to the remarks field
7. WHEN the edit succeeds, THE Receivings_Page SHALL display the success message "{OrderNo} を更新しました。"
8. IF the target order does not exist or OrderStatus is not 50 or 60, THEN THE Receivings_Page SHALL display the error message "対象の発注が見つからないか、編集できない状態です。"

### 要件 8: PDF出力（入庫伝票）

**ユーザーストーリー:** 倉庫担当者として、入庫伝票をPDFで出力できることで、紙ベースの確認作業や記録保管に活用したい。

#### 受入基準

1. THE Receivings_Page SHALL provide a PDF export button to generate 入庫伝票
2. THE Receivings_Page SHALL generate the PDF using QuestPDF with A4 page size and "Yu Gothic" font
3. THE Receivings_Page SHALL group orders by DeliveryDate and WarehouseCode, with each group on a separate page
4. THE Receivings_Page SHALL apply the current filters (DateFrom, DateTo, WarehouseFilter, StatusFilter) to the PDF export data
5. WHEN the PDF is generated, THE Receivings_Page SHALL include the following columns per group: No., 品番, 品目, 入目, 個数, 数量, 発注者, ロットNo., 確認, 備考
6. THE Receivings_Page SHALL include a header section showing 納入日 and 倉庫 for each group
7. THE Receivings_Page SHALL include a stamp area (確認 / 依頼担当) in the header for manual signatures
8. THE Receivings_Page SHALL name the output file "入庫伝票_{DateFrom}_{DateTo}.pdf" with dates in yyyyMMdd format
9. IF no matching data exists, THEN THE Receivings_Page SHALL generate a single page with the message "該当するデータはありません。"

### 要件 9: 認可制御

**ユーザーストーリー:** システム管理者として、入庫管理ページへのアクセスが権限制御されていることで、不正な操作を防止したい。

#### 受入基準

1. THE Receivings_Page SHALL require authentication via [Authorize(Policy = "DbPermissionCheck")]
2. IF a user does not have the required permission, THEN THE Receivings_Page SHALL deny access

### 要件 10: 操作者トレーサビリティ — 入庫者名（2026/05/27実装済み）

**ユーザーストーリー:** 管理者として、入庫操作の実行者名が記録・表示されることで、誰が入庫処理を行ったかを追跡できる。

#### 受入基準

1. WHEN 入庫が実行されたとき, THE Receivings_Page SHALL 入庫者名（user_name）を t_receivings に保存する
2. THE Receivings_Page SHALL 「入庫者」列を入庫一覧に表示する（ReceiverNames Dictionary で表示）
3. THE Receivings_Page SHALL 操作者名としてユーザーの LastName を使用する
4. WHEN 入庫取消が実行されたとき, THE Receivings_Page SHALL 入庫レコード削除により入庫者情報も自動クリアする

### 要件 11: UI統一（2026/05/27実装済み）

**ユーザーストーリー:** 倉庫担当者として、統一されたUI表示を得ることで、操作に迷わず効率的に業務を遂行できる。

#### 受入基準

1. THE Receivings_Page SHALL ページ先頭に `<partial name="_MaterialStyles" />` を配置する
2. THE Receivings_Page SHALL コンテナに `material-page` クラスを適用する
3. THE Receivings_Page SHALL タイトルを `<h5 class="mb-2">` で表示する
4. THE Receivings_Page SHALL テーブルのフォントサイズを 0.75rem で統一する
