# 実装計画: 受払台帳ページ（品目別入出庫残高一覧）

## 概要

受払台帳ページ（StockLedger/Index）のPageModel・ビュー・ViewModelを実装する。期間フィルタ・表示モードフィルタによるデータ取得、左右分離レイアウト（属性エリア + データテーブル）、2段表示（数量+個数）、計画在庫の累積計算、計画データのAJAX保存機能を含む。

## タスク

- [x] 1. データモデル・ViewModel実装
  - [x] 1.1 MItem エンティティ拡張（Concentration, SpecificGravity, PackageTypeName プロパティ追加）
    - m_items テーブルに concentration, specific_gravity, package_type_name カラム追加
    - _要件: 4.1_
  - [x] 1.2 StockLedgerListViewModel 作成（PlantName, DateFrom, DateTo, ItemGroups）
    - _要件: 3.1_
  - [x] 1.3 StockLedgerItemGroup 作成（品目属性12項目 + Rows + 合計フィールド）
    - ItemCode, ItemName, Unit, UnitContentQty, 属性情報10項目, Rows, Total*/Final* フィールド
    - _要件: 4.1, 7.1, 7.3_
  - [x] 1.4 StockLedgerRow 作成（RecordDate + 繰越 + 計画6項目 + 実績6項目 + Unit/UnitContentQty）
    - _要件: 6.1, 8.1, 8.2, 8.3_
  - [x] 1.5 PlanCellSaveRequest DTO 作成（ItemId, Date, Qty）
    - _要件: 9.1, 9.3_

- [x] 2. PageModel実装
  - [x] 2.1 OnGetAsync — データ取得・ViewModel構築
    - DateFrom/DateTo デフォルト値設定（当月1日〜末日）
    - t_stock_ledgers, t_order_forecasts, t_consumption_forecasts から期間内データ取得
    - ItemId/ItemCode でグループ化、forecast データマージ、StockLedgerRow 生成
    - 期間初日・最終日の補完行挿入
    - PlanStockQty/PlanStockCount 累積計算（running total）
    - m_items, m_purchase_conditions, m_suppliers から属性情報付加
    - DisplayMode フィルタ適用（"minus" → FinalStockCount < 0 or FinalStockQty < 0）
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 8.1, 8.2, 8.3, 8.4_
  - [x] 2.2 OnPostSavePlanReceiptAsync — 計画入庫AJAX保存
    - PlanCellSaveRequest を受信、t_order_forecasts の既存レコード検索
    - 既存あり → ForecastOrderQty 更新、既存なし → 新規作成（LotSizeType="manual"）
    - JSON { success: true/false } を返却
    - _要件: 9.1, 9.2, 9.5, 9.6_
  - [x] 2.3 OnPostSavePlanDispatchAsync — 計画出庫AJAX保存
    - PlanCellSaveRequest を受信、t_consumption_forecasts の既存レコード検索
    - 既存あり → ForecastQty 更新、既存なし → 新規作成（SourceId=1, UserId=User.Identity.Name）
    - JSON { success: true/false } を返却
    - _要件: 9.3, 9.4, 9.5, 9.6_

- [x] 3. ビュー実装
  - [x] 3.1 期間フィルタUI（DateFrom, DateTo, DisplayMode ドロップダウン, 表示ボタン）
    - form(method="get") 内に d-flex align-items-end gap-3 で配置
    - DisplayMode: "在庫マイナスのみ"(minus, default) / "全件"(all)
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2_
  - [x] 3.2 カードヘッダー（タイトル + プラント名 + 期間表示）
    - card-header に "品目別入出庫残高一覧（在庫品・受託品）" + プラント名・期間
    - _要件: 3.1_
  - [x] 3.3 左側属性エリア（Left_Attribute_Area）
    - div.flex-shrink-0 (width: 220px)、table.table.table-sm.mb-0 (border-0)
    - 12属性をラベル・値ペアで表示、null時は"-"
    - _要件: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4_
  - [x] 3.4 右側データテーブル — 3段ヘッダー構成
    - colgroup で列幅固定（年月日62px, 数値70px, 単位30px）
    - 3段ヘッダー: 計画/実績 → 入庫/出庫/在庫 → 数量個数/単位
    - 計画列ヘッダー背景: #f5f0d0
    - _要件: 5.1, 5.2, 5.3, 5.4, 6.8_
  - [x] 3.5 右側データテーブル — データ行（2段表示）
    - 各日付エントリを2行で表示: row1=数量(N3)+単位, row2=個数(N0)+"個"
    - 年月日セル rowspan=2、計画列データ背景: #fdfbf0
    - _要件: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - [x] 3.6 右側データテーブル — 合計行（計）
    - table-warning + fw-bold、"計" rowspan=2
    - 計画・実績の入庫合計/出庫合計/最終在庫を2段表示
    - _要件: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 4. 認可設定
  - [x] 4.1 PageModel に [Authorize(Policy = "DbPermissionCheck")] 属性を適用
    - _要件: 10.1, 10.2_
