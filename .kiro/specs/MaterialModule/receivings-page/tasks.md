# 実装計画: 入庫管理ページ

## 概要

入庫管理ページ（Receivings/Index）のPageModel・PDF生成・ビューを実装する。注文確定（50）/入庫済み（60）の一覧表示、個別/一括入庫処理（在庫増加・TReceiving作成）、入庫取消、インライン編集、入庫伝票PDF出力を含む。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 一覧表示（OnGetAsync、フィルタ・ソート・ページネーション）
    - Status 50/60の発注を取得、DateFrom/DateTo（デフォルト今日）・ReceivedDateFrom/To・WarehouseFilter・StatusFilterによるフィルタ
    - ソート（delivery/orderno/itemcode/itemname/qty/dest/date/received/warehouse）、ページネーション（10/20/30/50）
    - IUserPreferenceServiceによるページサイズ永続化
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  - [x] 1.2 個別入庫（OnPostReceiveAsync、在庫増加・TReceiving作成）
    - OrderStatusHelper.UpdateWithLockAsync（expectedStatus=50）でStatus 50→60更新
    - ReceivedDate=今日設定、TReceivingレコード作成、IStockService.IncrementStockAsync呼び出し
    - _要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_
  - [x] 1.3 一括入庫（OnPostBulkReceiveAsync）
    - 未選択時エラー"入庫する発注を選択してください。"
    - OrderStatusHelper.BulkUpdateWithLockAsyncで一括Status更新、各orderにTReceiving作成＋在庫増加
    - _要件: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - [x] 1.4 入庫取消（OnPostUnreceiveAsync、TReceiving削除）
    - OrderStatusHelper.UpdateWithLockAsync（expectedStatus=60）でStatus 60→50更新
    - ReceivedDate=null、t_receivingsから該当OrderIdのレコード全削除
    - _要件: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_
  - [x] 1.5 インライン編集（OnPostEditAsync、個数変更時備考追記）
    - Status 50/60のorderに対してOrderQty・LotNo・Remarks・ReceivedDate更新
    - 個数変更時: TotalQty再計算、Amount再計算、備考に"個数変更: {旧}→{新}"追記
    - _要件: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  - [x] 1.6 倉庫マスタ読み込み（LoadWarehousesAsync）
    - IMasterServiceから有効倉庫リスト取得、SelectListItem構築
    - _要件: 3.3_

- [x] 2. PDF生成実装
  - [x] 2.1 入庫伝票PDF（OnGetExportPdfAsync、QuestPDF、日付+倉庫グループ化）
    - QuestPDF Community License、A4、Yu Gothicフォント
    - DeliveryDate + WarehouseCodeでグループ化（グループごとに1ページ）
    - ヘッダー: 納入日テーブル＋印枠（確認/依頼担当）
    - 明細テーブル: No.・品番・品目・入目・個数・数量・発注者・ロットNo.・確認・備考
    - ファイル名: "入庫伝票_{DateFrom}_{DateTo}.pdf"
    - _要件: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9_

- [x] 3. ビュー実装
  - [x] 3.1 フィルタUI（納入日・入庫日・倉庫・ステータス）
    - 納入日範囲（DateFrom/DateTo、デフォルト今日）、入庫日範囲、倉庫ドロップダウン、ステータス選択
    - _要件: 3.1, 3.2, 3.3, 3.4_
  - [x] 3.2 一覧テーブル（ソートリンク・チェックボックス・編集ボタン）
    - ソートリンク付きヘッダー、Status=50時にチェックボックス＋入庫ボタン、Status=60時に戻すボタン
    - 編集ボタン（モーダル起動）
    - _要件: 1.2, 4.1, 6.1_
  - [x] 3.3 インライン編集モーダル
    - 個数・ロットNo・備考・入庫日の編集フォーム、Status=50時は入庫日非表示
    - _要件: 7.1, 7.3, 7.4_
  - [x] 3.4 ページネーション
    - ページサイズ選択（10/20/30/50）、ページネーションコントロール、フィルタ値保持
    - _要件: 1.3, 3.6_

