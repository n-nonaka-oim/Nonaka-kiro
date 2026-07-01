# 実装計画: 需要予測ページ

## 概要

需要予測ページ（Forecasts/Index）のPageModel・ビューを実装する。品目選択による現在庫表示、消費予測の登録・一覧表示・削除、在庫受払履歴セクションを含む。PRGパターンによる二重送信防止を採用。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 品目選択・データ読み込み（OnGetAsync）
    - LoadItemsAsyncで品目ドロップダウン構築、ItemId有効時にLoadItemDataAsync呼び出し
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  - [x] 1.2 予測登録（OnPostSaveAsync、バリデーション・PRGパターン）
    - ItemId未選択時エラー"品目を選択してください。"、ForecastQty<=0時エラー"予測数量は0より大きい値を入力してください。"
    - IConsumptionForecastProvider.SaveForecastAsync呼び出し、RedirectToPageでPRGリダイレクト
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  - [x] 1.3 予測削除（OnPostDeleteAsync）
    - IConsumptionForecastProvider.DeleteForecastAsync呼び出し、RedirectToPageでリダイレクト
    - _要件: 5.1, 5.2, 5.3, 5.4_
  - [x] 1.4 品目リスト読み込み（LoadItemsAsync）
    - IMasterService.GetActiveItemsAsyncで全有効品目取得、"{ItemCode} - {ItemName}"形式でSelectListItem構築
    - _要件: 1.1, 1.2_
  - [x] 1.5 品目データ読み込み（LoadItemDataAsync、在庫合計・予測一覧）
    - IStockService.GetStocksByItemAsyncで全倉庫在庫取得→Sum(StockQty)でCurrentStockQty算出
    - IConsumptionForecastProvider.GetForecastRecordsAsync（±3ヶ月範囲）で予測一覧取得
    - StockLedgerHistory = []（TODO: 受払台帳画面で対応）
    - _要件: 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 2. ビュー実装
  - [x] 2.1 品目選択ドロップダウン（onchange自動サブミット）
    - form(method="get")内にselect配置、onchange="this.form.submit()"で自動リロード
    - プレースホルダー"-- 品目を選択 --"（value=""）
    - _要件: 1.1, 1.2, 1.3, 1.4_
  - [x] 2.2 現在庫表示（バッジ）
    - "現在庫"カード内にbadge(bg-info)でCurrentStockQty表示（N2形式）
    - _要件: 2.1, 2.2, 2.3, 2.4_
  - [x] 2.3 予測登録フォーム（日付・数量・備考）
    - 予測日(date、デフォルト今日)、予測数量(number、min="0.01"、step="any")、備考(text、maxlength=256)、"登録"ボタン
    - _要件: 3.1, 3.2, 3.3, 3.4_
  - [x] 2.4 予測一覧テーブル（削除ボタン付き）
    - テーブル列: 予測日(yyyy-MM-dd)・予測数量(N2、右寄せ)・備考・登録者・更新日時(yyyy-MM-dd HH:mm)・削除ボタン
    - レコードなし時"登録済みの消費予測はありません。"表示
    - 削除ボタンクリック時confirm("この予測を削除しますか？")
    - _要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2_
  - [x] 2.5 在庫受払履歴セクション（TODO）
    - "在庫受払履歴（直近30件）"セクション、テーブル列: 日付・繰越数量・入庫数量・出庫数量・在庫数量
    - 数値はN2形式・右寄せ、null時"-"表示
    - レコードなし時"在庫受払履歴はありません。"表示
    - _要件: 6.1, 6.2, 6.3, 6.4_

