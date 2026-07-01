# 実装計画: 発注管理ページ

## 概要

発注管理モジュール（Orders）の3画面（発注エントリ・発注確認・発注検索）のPageModel・ビュー・AJAX機能を実装する。品目検索オートコンプリート、エントリCRUD、一括登録、確認/取消操作、検索・PDF/Excel出力を含む。

## タスク

- [x] 1. Orders/Create PageModel実装
  - [x] 1.1 品目検索AJAX（OnGetSearchSuggestAsync）
    - キーワードに基づく品目検索（最大20件）をIMasterService.SearchItemsAsync経由で実装
    - keyword空の場合は空配列を返却
    - _要件: 1.1, 1.2_
  - [x] 1.2 品目詳細取得AJAX（OnGetItemDetailAsync）
    - 品目詳細・購買条件・営業日計算によるデフォルト納期日を返却
    - IMasterService.GetItemDetailAsync、GetPurchaseConditionForItemAsync、GetBusinessDayAfterAsyncを呼び出し
    - _要件: 1.3, 1.4, 1.5, 1.6_
  - [x] 1.3 エントリ追加（OnPostAddAsync）
    - バリデーション（ItemId<=0、OrderQty<=0）、TOrder作成（Status=10）、デフォルト数量自動保存
    - _要件: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  - [x] 1.4 エントリ削除（OnPostRemoveAsync）
    - 指定エントリIDのTOrderレコードを削除
    - _要件: 3.4_
  - [x] 1.5 一括登録（OnPostSubmitAsync）
    - 選択エントリのOrderStatusを10→20に更新、未選択時エラーメッセージ表示
    - _要件: 4.1, 4.2, 4.3, 4.4_
  - [x] 1.6 ページデータ読み込み（LoadPageDataAsync）
    - ユーザーのエントリ一覧取得（Status=10）、ソート・ページネーション適用、倉庫ドロップダウン構築
    - _要件: 3.1, 3.2, 3.3, 3.5, 14.1, 14.2, 14.3_

- [x] 2. Orders/Create ビュー実装
  - [x] 2.1 入力フォーム（品目サジェスト・数量・納期・倉庫・出力区分・備考）
    - 品目検索テキストボックス、数量入力、納期日付、倉庫ドロップダウン、出力区分、備考テキストエリア
    - _要件: 2.1_
  - [x] 2.2 エントリリスト（テーブル・ソート・ページネーション）
    - ページサイズ選択（10/20/30/50）、ソートリンク、チェックボックス付きテーブル、ページネーションコントロール
    - _要件: 3.1, 3.2, 3.3_
  - [x] 2.3 JavaScript（サジェスト・キーボード操作・数量計算・全選択・確認ダイアログ）
    - debounce付きAJAX品目検索、ArrowUp/Down/Enter/Escapeキーボードナビゲーション、デフォルト数量・納期自動入力、全選択チェックボックス、登録確認ダイアログ
    - _要件: 1.1, 1.2, 1.3, 1.5, 1.6, 4.1_

- [x] 3. Orders/Confirm PageModel実装
  - [x] 3.1 一覧表示（OnGetAsync、ビュー切替・フィルタ・ソート）
    - StatusView（before=30/after=50）によるビュー切替、検索フィルタ（AND結合）、ソート、ページネーション
    - _要件: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_
  - [x] 3.2 個別確定（OnPostConfirmAsync）
    - OrderStatusHelper.UpdateWithLockAsyncで30→50に更新、成功メッセージ表示
    - _要件: 7.1, 7.2, 7.6_
  - [x] 3.3 一括確定（OnPostBulkConfirmAsync）
    - 選択発注のステータスを30→50に一括更新、未選択時エラー
    - _要件: 7.3, 7.4, 7.5_
  - [x] 3.4 確定取消（OnPostUnconfirmAsync）
    - OrderStatusHelper.UpdateWithLockAsyncで50→30に更新
    - _要件: 8.1, 8.2, 8.3_
  - [x] 3.5 インライン編集（OnPostEditAsync）
    - OrderQty・DeliveryDate更新、TotalQty・Amount再計算、UnitContentQty反映
    - _要件: 9.1, 9.2, 9.3, 9.4_

- [x] 4. Orders/Confirm ビュー実装
  - [x] 4.1 検索フィルタUI（発注番号・品目・日付・送付先・発注者）
    - フィルタフォーム（GET送信）、発注者ドロップダウン、日付範囲入力
    - _要件: 6.1, 6.2, 6.3_
  - [x] 4.2 一覧テーブル（ソート・ページネーション・チェックボックス）
    - ソートリンク付きテーブルヘッダー、チェックボックス（before時）、ページサイズ選択、ページネーション
    - _要件: 6.4, 6.5_
  - [x] 4.3 インライン編集モーダル
    - 数量・納期の編集フォーム、確認ダイアログ
    - _要件: 9.1_

- [x] 5. Orders/Search PageModel実装
  - [x] 5.1 検索クエリ構築（BuildQuery）
    - 全フィルタ条件をAND結合でIQueryable構築、デフォルトソート（OrderDate DESC, Id DESC）
    - _要件: 10.1, 10.2, 10.3, 10.4, 10.5_
  - [x] 5.2 PDF出力（OnGetDownloadPdfAsync）
    - IOrderPdfService.GenerateOrderPdfAsyncで個別PDF生成、application/pdfで返却
    - _要件: 11.1, 11.2_
  - [x] 5.3 Excel出力（OnGetExportExcelAsync）
    - ClosedXMLで全件出力（ページネーション無視）、ヘッダー太字・灰色背景、列幅自動調整
    - _要件: 12.1, 12.2, 12.3, 12.4_

- [x] 6. Orders/Search ビュー実装
  - [x] 6.1 検索フォーム（全フィルタ条件）
    - 発注番号・品目コード・品目名・ステータス・発注日範囲・納期範囲・発注者・送付先・仕入先・倉庫の入力フィールド
    - _要件: 10.1, 10.3_
  - [x] 6.2 結果テーブル（ページネーション）
    - 検索結果テーブル、ページサイズ選択、ページネーションコントロール
    - _要件: 10.4_
  - [x] 6.3 PDF/Excelダウンロードボタン
    - 個別PDFダウンロードボタン、Excel一括エクスポートボタン
    - _要件: 11.1, 12.1_

