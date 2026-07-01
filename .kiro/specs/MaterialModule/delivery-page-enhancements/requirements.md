# 要件定義書

## はじめに

出庫管理ページ（Delivery/Index）に対するUI/UX改善。既存の動作する画面に対して、文言変更・フィルタ追加・ステータス操作の拡張を行う。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **Delivery_Page**: MaterialModule/Areas/Material/Pages/Delivery/Index に配置された出庫管理画面
- **TDispatch**: 出庫データを格納するエンティティ（t_dispatches テーブル）
- **Status**: TDispatchのステータス値。1=搬入前、2=搬入済
- **WarehouseFilter**: 倉庫による絞り込みフィルタ（BindProperty、SupportsGet対応）
- **DepartmentFilter**: 請求部門による絞り込みフィルタ（既存実装済み）
- **CompletedAt**: TDispatchの搬入完了日時フィールド

## 要件

### 要件 1: ページタイトル変更

**ユーザーストーリー:** 運搬担当者として、画面タイトルが業務内容を正確に反映していることで、操作対象を明確に把握したい。

#### 受入基準

1. THE Delivery_Page SHALL display "出庫管理" as the page title instead of "運搬管理"

### 要件 2: リストヘッダー変更

**ユーザーストーリー:** 運搬担当者として、リストの見出しが業務用語と一致していることで、表示内容を直感的に理解したい。

#### 受入基準

1. THE Delivery_Page SHALL display "出庫リスト" as the card header text instead of "運搬リスト"

### 要件 3: 倉庫フィルタ追加

**ユーザーストーリー:** 運搬担当者として、倉庫ごとに出庫データを絞り込めることで、担当倉庫の作業に集中したい。

#### 受入基準

1. THE Delivery_Page SHALL display a "倉庫" dropdown filter in the search area
2. WHEN no warehouse is selected, THE Delivery_Page SHALL display records from all warehouses (default = "全倉庫")
3. WHEN a warehouse is selected, THE Delivery_Page SHALL display only records matching the selected warehouse
4. THE Delivery_Page SHALL populate the warehouse dropdown dynamically from distinct WarehouseName values in existing dispatch data with Status 1 or 2
5. WHEN pagination, sorting, or form submission occurs, THE Delivery_Page SHALL preserve the selected WarehouseFilter value via hidden fields and route parameters

### 要件 4: 列ヘッダー名変更

**ユーザーストーリー:** 運搬担当者として、操作列の名称が実際の操作内容を示していることで、ボタンの意味を即座に理解したい。

#### 受入基準

1. THE Delivery_Page SHALL display "搬入" as the column header instead of "操作"

### 要件 5: ステータス表示・メッセージ変更

**ユーザーストーリー:** 運搬担当者として、ステータスや確認メッセージが搬入業務の用語で統一されていることで、操作の意図を正確に把握したい。

#### 受入基準

1. WHEN a record has Status=2, THE Delivery_Page SHALL display the badge text "搬入済" instead of "完了"
2. WHEN a record has Status=1, THE Delivery_Page SHALL display the badge text "搬入前" instead of "未完了"
3. WHEN a user clicks the individual complete button, THE Delivery_Page SHALL show the confirm message "搬入完了しますか？" instead of "運搬完了しますか？"
4. WHEN a user clicks the bulk complete button, THE Delivery_Page SHALL show the confirm message "選択した項目を搬入完了しますか？" instead of "選択した項目を運搬完了しますか？"
5. WHEN individual completion succeeds, THE Delivery_Page SHALL display the success message "搬入完了しました。" instead of "運搬完了しました。"
6. WHEN bulk completion succeeds, THE Delivery_Page SHALL display the success message "{count} 件を搬入完了しました。" instead of "{count} 件を運搬完了しました。"

### 要件 6: 搬入済レコードの「戻す」ボタン追加

**ユーザーストーリー:** 運搬担当者として、誤って搬入完了にしたレコードを元に戻せることで、操作ミスを修正したい。

#### 受入基準

1. WHEN a record has Status=2, THE Delivery_Page SHALL display a "戻す" button in the action column
2. WHEN a user clicks the "戻す" button, THE Delivery_Page SHALL show the confirm message "搬入前に戻しますか？"
3. WHEN the revert is confirmed, THE Delivery_Page SHALL update the TDispatch record by setting Status to 1 and clearing CompletedAt to null
4. WHEN the revert succeeds, THE Delivery_Page SHALL display the success message "搬入前に戻しました。"
5. IF the target TDispatch record does not exist or Status is not 2, THEN THE Delivery_Page SHALL display an error message "対象が見つからないか、戻せない状態です。"
6. WHEN the revert completes, THE Delivery_Page SHALL preserve the current search filters (DateFrom, DateTo, DepartmentFilter, WarehouseFilter)

### 要件 7: 操作者トレーサビリティ — 搬入者名（2026/05/27実装済み）

**ユーザーストーリー:** 管理者として、搬入完了の実行者名が記録・表示されることで、誰が搬入処理を行ったかを追跡できる。

#### 受入基準

1. WHEN 搬入完了が実行されたとき, THE Delivery_Page SHALL 搬入者ID（completed_by）、搬入者名（completed_by_name）を t_dispatches に保存する
2. WHEN 搬入完了が取り消されたとき, THE Delivery_Page SHALL completed_by, completed_by_name をクリアする
3. THE Delivery_Page SHALL 「搬入者」列を搬入一覧に表示する
4. THE Delivery_Page SHALL 操作者名としてユーザーの LastName を使用する

### 要件 8: UI統一（2026/05/27実装済み）

**ユーザーストーリー:** 運搬担当者として、統一されたUI表示を得ることで、操作に迷わず効率的に業務を遂行できる。

#### 受入基準

1. THE Delivery_Page SHALL ページ先頭に `<partial name="_MaterialStyles" />` を配置する
2. THE Delivery_Page SHALL コンテナに `material-page` クラスを適用する
3. THE Delivery_Page SHALL タイトルを `<h5 class="mb-2">` で表示する
4. THE Delivery_Page SHALL テーブルのフォントサイズを 0.75rem で統一する
