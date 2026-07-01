# 要件定義書

## はじめに

MRP計算ページ（Mrp/Index）の機能仕様。在庫アラートの表示、品目別または全品目のMRP（資材所要量計画）計算の実行、計算結果の表示、および予測結果から仮発注への変換を行う画面。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **Mrp_Page**: MaterialModule/Areas/Material/Pages/Mrp/Index に配置されたMRP実行画面
- **MRP**: Material Requirements Planning（資材所要量計画）。在庫・消費予測・リードタイムから発注計画を自動算出する手法
- **IRequirementCalculationService**: MRP計算を担うサービスインターフェース
- **IAlertService**: 在庫アラート取得を担うサービスインターフェース
- **IOrderService**: 発注関連操作を担うサービスインターフェース（仮発注作成含む）
- **IMasterService**: マスタデータ取得を担うサービスインターフェース
- **TOrderForecast**: MRP計算結果エンティティ（発注予測）
- **MrpForecastViewModel**: MRP結果表示用ビューモデル
- **StockAlertDto**: 在庫アラートDTO（ItemId, ItemCode, ItemName, CurrentStockQty, StockMinimumQty, SafetyStockQty, ShortageDate, ForecastOrderDate, LeadTimeDays, AlertLevel）
- **AlertLevel**: アラートレベル（Red=即時対応, Orange=納期超過, Yellow=3日以内, Green=正常）
- **IsConverted**: 仮発注への変換済みフラグ
- **LotSizeType**: ロットサイズ方式（fixed_qty=固定数量, lot_for_lot=ロットフォーロット）

## 要件

### 要件 1: 在庫アラート表示

**ユーザーストーリー:** 購買担当者として、在庫不足のアラートを確認できることで、緊急対応が必要な品目を即座に把握したい。

#### 受入基準

1. THE Mrp_Page SHALL display stock alerts via `IAlertService.GetStockAlertsAsync()` in the "在庫アラート" section
2. THE alert table SHALL display the following columns: レベル, 品目コード, 品目名, 現在庫, 最低在庫, 安全在庫, 発注予定日, リードタイム, アクション
3. THE AlertLevel SHALL be displayed as a badge with the following mapping: Red="即時対応"(bg-danger), Orange="納期超過"(bg-warning), Yellow="3日以内"(bg-info), Green="正常"(bg-success)
4. THE alert row SHALL apply CSS class based on AlertLevel: Red=table-danger, Orange=table-warning, Yellow=table-info, Green=table-success
5. THE リードタイム column SHALL display as "{LeadTimeDays} 日"
6. WHEN StockMinimumQty or SafetyStockQty is null, THE Mrp_Page SHALL display "-"
7. WHEN ForecastOrderDate is null, THE Mrp_Page SHALL display "-"
8. THE Mrp_Page SHALL display a "手動発注" link for each alert row that navigates to Orders/Create with the ItemId parameter
9. WHEN no alerts exist, THE Mrp_Page SHALL display "アラートはありません。"

### 要件 2: MRP計算実行

**ユーザーストーリー:** 購買担当者として、MRP計算を実行できることで、最適な発注計画を自動的に算出したい。

#### 受入基準

1. THE Mrp_Page SHALL display a calculation form with fields: 対象品目(dropdown), 開始日(date), 終了日(date)
2. THE item dropdown SHALL include all active items via `IMasterService.GetActiveItemsAsync()` with format "{ItemCode} - {ItemName}"
3. THE item dropdown SHALL include a "-- 全品目 --" option with empty value for calculating all items
4. THE 開始日 (FromDate) SHALL default to today
5. THE 終了日 (ToDate) SHALL default to today + 3 months
6. WHEN a specific item is selected and "MRP実行" is clicked, THE Mrp_Page SHALL call `IRequirementCalculationService.CalculateRequirementsAsync(ItemId, FromDate, ToDate)`
7. WHEN "-- 全品目 --" is selected and "MRP実行" is clicked, THE Mrp_Page SHALL call `IRequirementCalculationService.CalculateAllItemRequirementsAsync(FromDate, ToDate)`
8. WHEN the calculation completes, THE Mrp_Page SHALL display the success message "MRP計算が完了しました。"
9. WHEN the calculation completes, THE Mrp_Page SHALL reload the stock alerts to reflect updated state

### 要件 3: MRP計算結果表示

**ユーザーストーリー:** 購買担当者として、MRP計算結果を確認できることで、発注計画の妥当性を検証し必要に応じて仮発注を作成したい。

#### 受入基準

1. WHEN an item is selected (via GET or after calculation), THE Mrp_Page SHALL display MRP results from TOrderForecast entity filtered by ItemId and ordered by ForecastDate
2. THE MRP results table SHALL display the following columns: 品目コード, 品目名, 予測日, 発注予定日, 総所要量, 正味所要量, 発注予定数量, 納期予定日, 予測在庫, ロット方式, 状態, アクション
3. THE 日付 columns SHALL be formatted as "yyyy-MM-dd"
4. THE 数量 columns SHALL be formatted with "N2" format and right-aligned
5. WHEN ForecastStockQty is null, THE Mrp_Page SHALL display "-"
6. THE ロット方式 column SHALL display "固定数量" for "fixed_qty" and "ロットフォーロット" for other values
7. THE 状態 column SHALL display "変換済み"(badge bg-secondary) when IsConverted=true, or "未変換"(badge bg-primary) when IsConverted=false
8. THE MRP results section SHALL only be displayed when MrpResults has items

### 要件 4: 仮発注変換

**ユーザーストーリー:** 購買担当者として、MRP計算結果から仮発注を作成できることで、計算結果を実際の発注プロセスに反映したい。

#### 受入基準

1. THE Mrp_Page SHALL display a "仮発注作成" button for each MRP result row
2. WHEN IsConverted is true, THE "仮発注作成" button SHALL be disabled
3. WHEN the "仮発注作成" button is clicked, THE Mrp_Page SHALL call `IOrderService.CreateProvisionalOrderAsync(forecastId, userId, userName)`
4. THE userId SHALL be obtained from `User.Identity.Name`
5. WHEN the conversion succeeds, THE Mrp_Page SHALL display the success message "仮発注を作成しました。"
6. WHEN the conversion succeeds, THE Mrp_Page SHALL reload the alerts and MRP results to reflect the updated state

### 要件 5: 品目選択による結果表示

**ユーザーストーリー:** 購買担当者として、品目を選択してMRP結果を確認できることで、特定品目の発注計画を詳細に確認したい。

#### 受入基準

1. THE ItemId parameter SHALL support GET binding (SupportsGet = true)
2. WHEN the page is loaded with a valid ItemId (> 0), THE Mrp_Page SHALL display existing MRP results for that item from TOrderForecast
3. THE MRP results SHALL include the related Item entity (via Include) for ItemCode and ItemName display
4. THE MRP results SHALL be ordered by ForecastDate ascending

### 要件 6: 認可制御

**ユーザーストーリー:** システム管理者として、MRPページへのアクセスが権限のあるユーザーに限定されることで、発注計画の不正操作を防止したい。

#### 受入基準

1. THE Mrp_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy

### 要件 7: パフォーマンス改善（2026/05/27実装済み）

**ユーザーストーリー:** 購買担当者として、MRPページが高速に表示されることで、業務効率が低下しない。

#### 受入基準

1. THE AlertService SHALL N+1クエリを排除し、一括クエリ（最大3回）でアラートデータを取得する
2. THE AlertService SHALL 在庫データソースを t_stock_ledgers に統一する（t_stocks は使用しない）
3. THE AlertService SHALL アラート判定基準を safety_stock_qty に統一し、Green（余裕あり）を除外して返却する
4. THE LoadOrderListAsync SHALL `Include` ではなく `Select` を使用し、必要列のみを取得する
5. THE Mrp_Page SHALL 一覧取得クエリにおいて、表示に不要なナビゲーションプロパティを読み込まない

### 要件 8: MRP発注数量計算方式（2026/05/27実装済み）

**ユーザーストーリー:** 購買担当者として、MRPの発注数量が正しく計算されることで、適切な数量で発注できる。

#### 受入基準

1. THE MRP_Calculator SHALL 発注数量を「安全在庫(safety_stock_qty) - 現在在庫(stock_qty) = 不足分」で計算する
2. THE Mrp_Page SHALL m_items.default_order_qty を発注数量の初期値として使用しない（NULLとする）
3. THE MRP_Calculator SHALL 計算結果を t_order_forecasts に保存する

### 要件 9: UI統一（2026/05/27実装済み）

**ユーザーストーリー:** 購買担当者として、統一されたUI表示を得ることで、操作に迷わず効率的に業務を遂行できる。

#### 受入基準

1. THE Mrp_Page SHALL ページ先頭に `<partial name="_MaterialStyles" />` を配置する
2. THE Mrp_Page SHALL コンテナに `class="container-fluid mt-3 px-4 material-page" style="font-size: 0.8rem;"` を設定する
3. THE Mrp_Page SHALL タイトルを `<h5 class="mb-2">` で表示する
4. THE Mrp_Page SHALL テーブルのフォントサイズを 0.75rem で統一する
5. THE Mrp_Page SHALL 「発注日」の表示名称を「起票日」に統一する
