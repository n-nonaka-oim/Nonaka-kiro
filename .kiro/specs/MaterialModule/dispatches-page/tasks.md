# 実装計画: 原材料工場入請求登録ページ

## 概要

原材料工場入請求登録ページ（Dispatches/Index）のPageModel・PDF生成・ビューを実装する。品目検索AJAX、在庫照会、エントリCRUD、一括登録（ステータス遷移＋在庫減算）、PDF伝票生成、戻し操作を含む。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 品目検索AJAX（OnGetSearchItemAsync）
    - IMasterService.SearchItemsAsyncでキーワード検索（最大20件）、JSON返却
    - _要件: 2.1, 2.2, 2.3_
  - [x] 1.2 在庫照会AJAX（OnGetStockAsync）
    - IStockService.GetStocksByItemAsyncで全倉庫の在庫情報取得、合計数量返却
    - _要件: 3.1, 3.2, 3.3_
  - [x] 1.3 エントリ追加（OnPostAddAsync）
    - バリデーション（ItemId<=0、Count==0、Location空）、TDispatch作成（Status=0）
    - 品目マスタから倉庫コード・倉庫名を自動設定、ユーザー所属から部署名・原価センターを設定
    - _要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_
  - [x] 1.4 エントリ削除（OnPostRemoveAsync）
    - 選択エントリ（Status=0、自ユーザーのみ）を削除、確認ダイアログ後に実行
    - _要件: 7.1, 7.2, 7.3, 7.4, 7.5_
  - [x] 1.5 一括登録＋在庫減算（OnPostSubmitAsync）
    - 選択エントリ（未選択時は全Status=0）のStatus 0→1更新、SubmittedAt設定
    - IStockService.DecrementStockAsyncで各エントリの在庫減算
    - PdfOutput=true時はPDF生成してFile返却、false時はリダイレクト
    - _要件: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_
  - [x] 1.6 戻し操作（OnPostRecoverAsync、SuperUserのみ）
    - SuperUserロールチェック（非SuperUserは403）、Status 1→0更新、SubmittedAt=null
    - _要件: 10.1, 10.2, 10.3, 10.4, 10.5_
  - [x] 1.7 搬入場所読み込み（LoadLocationsAsync、セクションフィルタ）
    - MDeliveryLocationからsection_idフィルタ（NULL/空 OR ユーザーsection_id一致）で取得
    - SortId昇順、distinct LocationName
    - _要件: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 1.8 ユーザー所属情報取得（GetUserDepartmentAsync）
    - SharedCore.IUserRepositoryからユーザー氏名・部署名・内線番号を取得
    - _要件: 6.1, 6.2, 6.3_

- [x] 2. PDF生成実装
  - [x] 2.1 GenerateDispatchPdf（QuestPDF、日付グループ化、A4）
    - QuestPDF Community Licenseで"原材料工場入請求伝票"を生成
    - DispatchDateでグループ化（日付ごとに1ページ）
    - ヘッダー: 部署名・原価センター・搬入年月日・請求者名・内線番号
    - 明細テーブル: 品名・品目コード・入目・個数・倉庫・備考・搬入場所
    - フォント: Yu Gothic、ファイル名: "工場入請求_{yyyyMMdd}.pdf"
    - _要件: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

- [x] 3. ビュー実装
  - [x] 3.1 入力フォーム（品目サジェスト・個数・搬入日・搬入場所・備考）
    - 品目検索テキストボックス、個数入力、搬入日（デフォルト当日）、搬入場所ドロップダウン、備考
    - _要件: 4.1, 5.1_
  - [x] 3.2 ビュー切替（未登録/搬入前）
    - "未登録"/"搬入前"トグルボタン、StatusViewパラメータによる表示切替
    - _要件: 1.1, 1.2, 1.3, 1.4_
  - [x] 3.3 エントリリスト（チェックボックス・全選択）
    - テーブル表示（No・搬入日・品目名・品目コード・入目・個数・倉庫・備考・搬入場所）
    - チェックボックス・全選択/解除・行クリック選択・件数表示
    - _要件: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_
  - [x] 3.4 JavaScript（サジェスト・在庫表示・行選択・登録処理）
    - debounce(300ms)付きfetch品目検索、キーボードナビゲーション、在庫合計表示
    - 全選択/解除連動、行クリックtoggle、削除ボタン制御、fetch POST登録→PDFダウンロード
    - _要件: 2.1, 2.4, 2.5, 2.6, 3.3, 11.4_

