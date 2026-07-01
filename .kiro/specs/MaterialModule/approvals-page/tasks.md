# 実装計画: 発注承認ページ

## 概要

発注承認ページ（Approvals/Index）のPageModel・ビューを実装する。ステータスフィルタによる一覧表示、個別/一括の承認・差戻し操作、Excelエクスポート、PDF個別ダウンロード、発注番号パースによるカスタムソートを含む。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 一覧表示（OnGetAsync、ステータスフィルタ・ソート・ページネーション）
    - StatusFilterに応じてGetPendingApprovalsAsync/GetApprovalHistoryAsyncを呼び分け
    - SortByに応じたソート適用（switch式）、デフォルトソート（StatusFilter=30時はOrderNoパース3段ソート）
    - IUserPreferenceServiceによるページサイズ永続化（ListKey="Approvals_Index"）
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 6.1, 6.2, 6.3, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  - [x] 1.2 個別承認（OnPostApproveAsync）
    - IApprovalService.ApproveOrderAsync呼び出し、成功時"承認しました。"、失敗時ex.Message
    - _要件: 2.1, 2.2, 2.3_
  - [x] 1.3 一括承認（OnPostBulkApproveAsync）
    - 未選択時エラー"承認する発注を選択してください。"、IApprovalService.ApproveOrdersAsync呼び出し
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  - [x] 1.4 個別差戻し（OnPostRejectAsync）
    - IApprovalService.RejectOrderAsync呼び出し、成功時"差戻ししました。"
    - _要件: 4.1, 4.2, 4.3_
  - [x] 1.5 一括差戻し（OnPostBulkRejectAsync）
    - 未選択時エラー"差戻しする発注を選択してください。"、各発注を個別にRejectOrderAsyncで処理
    - _要件: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - [x] 1.6 Excelエクスポート（OnGetExportExcelAsync）
    - ClosedXMLでStatusFilterに応じた全件出力、ヘッダー太字・灰色背景、列幅自動調整
    - ファイル名: "発注一覧_{statusName}_{yyyyMMdd}.xlsx"
    - _要件: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_
  - [x] 1.7 PDF個別ダウンロード（OnGetDownloadPdfAsync）
    - IOrderPdfService.GenerateOrderPdfAsync呼び出し、"{orderNo}.pdf"で返却
    - _要件: 10.1, 10.2, 10.3_
  - [x] 1.8 発注番号パース関数（ExtractOrderNoDate/Group/Seq）
    - ハイフン区切りでdate(parts[1])、group(int parts[2])、seq(int parts[3])を抽出
    - null/空文字時はデフォルト値返却
    - _要件: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 2. ビュー実装
  - [x] 2.1 ステータスフィルタドロップダウン
    - 未承認(20)・承認済(30)・差戻し(15)の選択肢、自動サブミット
    - _要件: 1.1, 1.2, 1.3_
  - [x] 2.2 一覧テーブル（ソートリンク・チェックボックス・バッジ）
    - StatusFilter=20時にチェックボックス列、StatusFilter=30時に発注番号列
    - 種別バッジ（手動/仮発注/自動）、ソートリンク付きヘッダー
    - _要件: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_
  - [x] 2.3 一括操作ボタン（承認・差戻し）
    - チェック数>0で有効化、確認ダイアログ表示
    - _要件: 3.5, 3.6, 5.5, 5.6_
  - [x] 2.4 ページネーション
    - ページサイズ選択（10/20/30/50）、ページネーションコントロール（first/prev/pages/next/last）
    - _要件: 8.1, 8.4, 8.6_
  - [x] 2.5 JavaScript（全選択・ボタン制御・確認ダイアログ）
    - #checkAllのchange→全.row-check同期、チェック数に応じたボタン有効化、差戻しフォームID転送
    - _要件: 3.5, 5.5, 5.7_

