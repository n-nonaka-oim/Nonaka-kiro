# 実装計画: MRP計算ページ

## 概要

MRP計算ページ（Mrp/Index）のPageModel・ビューを実装する。在庫アラート表示、品目別/全品目のMRP計算実行、計算結果表示（TOrderForecast→ViewModel変換）、仮発注変換機能を含む。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 アラート・結果表示（OnGetAsync）
    - LoadItemsAsyncで品目ドロップダウン構築、IAlertService.GetStockAlertsAsyncでアラート取得
    - ItemId有効時にLoadMrpResultsAsyncで既存MRP結果表示
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 5.1, 5.2, 5.3, 5.4_
  - [x] 1.2 MRP計算実行（OnPostCalculateAsync、単一品目/全品目）
    - ItemId有効時: IRequirementCalculationService.CalculateRequirementsAsync(ItemId, FromDate, ToDate)
    - ItemId未選択時: IRequirementCalculationService.CalculateAllItemRequirementsAsync(FromDate, ToDate)
    - 計算後にアラート再取得、結果再表示、SuccessMessage="MRP計算が完了しました。"
    - _要件: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_
  - [x] 1.3 仮発注変換（OnPostConvertAsync）
    - IOrderService.CreateProvisionalOrderAsync(forecastId, userId, userName)呼び出し
    - アラート・結果再読み込み、SuccessMessage="仮発注を作成しました。"
    - _要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  - [x] 1.4 品目リスト読み込み（LoadItemsAsync）
    - IMasterService.GetActiveItemsAsyncで全有効品目取得、"-- 全品目 --"オプション追加
    - "{ItemCode} - {ItemName}"形式でSelectListItem構築
    - _要件: 2.2, 2.3_
  - [x] 1.5 MRP結果読み込み（LoadMrpResultsAsync、ViewModel変換）
    - context.OrderForecasts.Include(f => f.Item).Where(ItemId).OrderBy(ForecastDate)
    - TOrderForecast → MrpForecastViewModel変換（ForecastId, ItemCode, ItemName, 各日付・数量フィールド, IsConverted）
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 2. ビュー実装
  - [x] 2.1 在庫アラートテーブル（レベル色分け・手動発注リンク）
    - テーブル列: レベル(バッジ)・品目コード・品目名・現在庫・最低在庫・安全在庫・発注予定日・リードタイム・アクション
    - AlertLevel→バッジ/行クラスマッピング（Red=bg-danger/table-danger, Orange=bg-warning/table-warning, Yellow=bg-info/table-info, Green=bg-success/table-success）
    - "手動発注"リンク（Orders/Create?ItemId=xxx）、アラートなし時"アラートはありません。"
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_
  - [x] 2.2 MRP計算フォーム（品目選択・期間指定）
    - 品目ドロップダウン（"-- 全品目 --"含む）、開始日(デフォルト今日)、終了日(デフォルト今日+3ヶ月)、"MRP実行"ボタン
    - _要件: 2.1, 2.2, 2.3, 2.4, 2.5_
  - [x] 2.3 MRP結果テーブル（仮発注作成ボタン・変換済みdisabled）
    - テーブル列: 品目コード・品目名・予測日・発注予定日・総所要量・正味所要量・発注予定数量・納期予定日・予測在庫・ロット方式・状態・アクション
    - 日付はyyyy-MM-dd形式、数量はN2形式・右寄せ、ForecastStockQty null時"-"
    - ロット方式: "fixed_qty"→"固定数量"、その他→"ロットフォーロット"
    - 状態: IsConverted=true→"変換済み"(bg-secondary)、false→"未変換"(bg-primary)
    - "仮発注作成"ボタン（IsConverted=true時disabled）
    - MrpResults.Any()の場合のみセクション表示
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 4.1, 4.2_

