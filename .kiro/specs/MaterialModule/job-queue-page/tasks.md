# 実装計画: 印刷キューページ

## 概要

印刷キューページ（JobQueue/Index）のPageModel・ビューを実装する。承認済み発注の印刷・FAX送信状況を発注番号グループ単位で一覧表示し、グループ単位でのPDFダウンロード、ステータスフィルタ、ソート、ページネーション機能を含む。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 一覧表示（OnGetAsync、グループ化・ソート・ページネーション）
    - t_order_reports JOIN t_orders（ReferenceCode=OrderNo、ReportType="order_approval"）
    - PrintStatusフィルタ（デフォルト=1:待機）、UserId=ログインユーザーでフィルタ
    - OrderNoの先頭3セグメントでGroupBy、各グループから先頭レコード情報でJobQueueGroupItem構築
    - SortByに応じたソート（orderno/dest/item/approved）、デフォルトApprovedAt降順
    - IUserPreferenceServiceによるページサイズ永続化（ListKey="JobQueue_Index"）
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 2.1, 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  - [x] 1.2 PDFダウンロード（OnGetDownloadPdfAsync）
    - IOrderPdfService.GenerateGroupOrderPdfAsync(orderNoGroup)でPDF生成、application/pdfで返却
    - _要件: 4.1, 4.2, 4.3_
  - [x] 1.3 グループキー抽出（ExtractGroupKey）
    - OrderNoを"-"で分割、セグメント>=3の場合は先頭3セグメントをjoin、それ以外はそのまま返却
    - _要件: 7.1, 7.2, 7.3_
  - [x] 1.4 ステータス選択肢構築（LoadStatuses）
    - 固定値で構築: 待機(1)・完了(2)・エラー(9)
    - _要件: 2.1, 2.2, 2.3_

- [x] 2. ビュー実装
  - [x] 2.1 ステータスフィルタ（自動サブミット）
    - ステータスドロップダウン（待機/完了/エラー）、onchange="this.form.submit()"で自動サブミット
    - _要件: 2.1, 2.4, 2.5_
  - [x] 2.2 一覧テーブル（ソートリンク・バッジ・PDFボタン）
    - テーブル列: No(連番)・発注番号[sort]・送付先[sort]・代表品目[sort]・件数・承認日時[sort]・印刷・FAX・PDF
    - 印刷/FAXバッジ: 0="対象外"(bg-secondary)、1="待機"(bg-warning)、2="完了"(bg-success)、9="エラー"(bg-danger)
    - PDFダウンロードボタン（bi-file-pdfアイコン）
    - データなし時"該当するデータはありません。"表示
    - _要件: 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 3.1, 3.2, 4.1, 5.1, 5.2_
  - [x] 2.3 ページネーション
    - ページサイズ選択（10/20/30/50）、ページネーションコントロール（first/prev/pages/next/last）
    - StatusFilterパラメータ保持
    - _要件: 6.1, 6.4, 6.7_
  - [x] 2.4 JavaScript（downloadAndOpenPdf関数）
    - fetch GETでPDF取得→blob→createObjectURL→ダウンロードリンク生成→click→cleanup
    - ファイル名: "{orderNoGroup}.pdf"
    - エラー時alert("PDF生成に失敗しました")
    - _要件: 4.4, 4.5_

