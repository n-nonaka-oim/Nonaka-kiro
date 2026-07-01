# 要件定義書

## はじめに

発注承認ページ（Approvals/Index）の機能仕様。承認権限を持つユーザーが未承認の発注を一覧表示し、個別または一括で承認・差戻しを行う。ステータスフィルタによる履歴参照、Excel出力、PDF個別ダウンロード機能を含む。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **Approvals_Page**: MaterialModule/Areas/Material/Pages/Approvals/Index に配置された発注承認画面
- **OrderStatus**: 発注のステータス値。20=未承認、30=承認済、15=差戻し
- **StatusFilter**: ステータスによる絞り込みフィルタ（BindProperty、SupportsGet対応）
- **OrderListDto**: 発注一覧表示用のデータ転送オブジェクト
- **IApprovalService**: 承認・差戻し・一覧取得を担うサービスインターフェース
- **IOrderPdfService**: 発注書PDF生成サービスインターフェース
- **IUserPreferenceService**: ユーザーごとのページサイズ設定を管理するサービス
- **OrderNo**: 発注番号。形式: `{prefix}-{date}-{group}-{seq}`（例: G201-260513-001-001）
- **PageSize**: 1ページあたりの表示件数（10, 20, 30, 50から選択）

## 要件

### 要件 1: ステータスフィルタによる一覧表示

**ユーザーストーリー:** 承認担当者として、ステータスごとに発注を絞り込めることで、未承認・承認済・差戻しの発注を効率的に確認したい。

#### 受入基準

1. THE Approvals_Page SHALL display a status dropdown filter with options: 未承認(20), 承認済(30), 差戻し(15)
2. WHEN no StatusFilter is specified, THE Approvals_Page SHALL display pending approvals (status=20) as the default view
3. WHEN a StatusFilter value is selected, THE Approvals_Page SHALL display only orders matching the selected status
4. WHEN StatusFilter=20, THE Approvals_Page SHALL retrieve orders via `IApprovalService.GetPendingApprovalsAsync()`
5. WHEN StatusFilter=30 or StatusFilter=15, THE Approvals_Page SHALL retrieve orders via `IApprovalService.GetApprovalHistoryAsync(statusValue)`
6. THE Approvals_Page SHALL display the list header as "未承認リスト", "承認済リスト", or "差戻しリスト" corresponding to the selected status
7. THE Approvals_Page SHALL display the total order count in the list header (例: "未承認リスト（5 件）")

### 要件 2: 個別承認

**ユーザーストーリー:** 承認担当者として、個別の発注を承認できることで、内容を確認した上で1件ずつ承認処理を行いたい。

#### 受入基準

1. WHEN a user submits the approve action for a specific orderId, THE Approvals_Page SHALL call `IApprovalService.ApproveOrderAsync(orderId, approvedBy)` to update the order status from 20 to 30
2. WHEN the approval succeeds, THE Approvals_Page SHALL display the success message "承認しました。"
3. IF the approval fails with InvalidOperationException, THEN THE Approvals_Page SHALL display the exception message as an error

### 要件 3: 一括承認

**ユーザーストーリー:** 承認担当者として、複数の発注をまとめて承認できることで、大量の未承認発注を効率的に処理したい。

#### 受入基準

1. WHEN StatusFilter=20, THE Approvals_Page SHALL display checkboxes for each pending order row and a "承認" bulk action button
2. WHEN no orders are selected and the bulk approve button is clicked, THE Approvals_Page SHALL display the error message "承認する発注を選択してください。"
3. WHEN one or more orders are selected and the bulk approve button is clicked, THE Approvals_Page SHALL call `IApprovalService.ApproveOrdersAsync(selectedOrderIds, approvedBy)`
4. WHEN the bulk approval succeeds, THE Approvals_Page SHALL display the success message "{count} 件の発注を承認しました。"
5. THE bulk approve button SHALL be disabled until at least one checkbox is selected
6. WHEN the user clicks the bulk approve button, THE Approvals_Page SHALL show a confirmation dialog "承認しますか？"

### 要件 4: 個別差戻し

**ユーザーストーリー:** 承認担当者として、不備のある発注を差戻しできることで、発注者に修正を促したい。

#### 受入基準

1. WHEN a user submits the reject action for a specific orderId, THE Approvals_Page SHALL call `IApprovalService.RejectOrderAsync(orderId, approvedBy)` to update the order status from 20 to 15
2. WHEN the rejection succeeds, THE Approvals_Page SHALL display the success message "差戻ししました。"
3. IF the rejection fails with InvalidOperationException, THEN THE Approvals_Page SHALL display the exception message as an error

### 要件 5: 一括差戻し

**ユーザーストーリー:** 承認担当者として、複数の発注をまとめて差戻しできることで、不備のある発注を効率的に処理したい。

#### 受入基準

1. WHEN StatusFilter=20, THE Approvals_Page SHALL display a "差戻し" bulk action button
2. WHEN no orders are selected and the bulk reject button is clicked, THE Approvals_Page SHALL display the error message "差戻しする発注を選択してください。"
3. WHEN one or more orders are selected and the bulk reject button is clicked, THE Approvals_Page SHALL reject each selected order individually via `IApprovalService.RejectOrderAsync(orderId, approvedBy)`
4. WHEN the bulk rejection succeeds, THE Approvals_Page SHALL display the success message "{count} 件を差戻ししました。"
5. THE bulk reject button SHALL be disabled until at least one checkbox is selected
6. WHEN the user clicks the bulk reject button, THE Approvals_Page SHALL show a confirmation dialog "差戻しますか？"
7. THE bulk reject form SHALL copy selected order IDs from the bulk approve form's checkboxes via JavaScript before submission

### 要件 6: ソート機能

**ユーザーストーリー:** 承認担当者として、一覧を任意の列で並べ替えられることで、確認したい発注を素早く見つけたい。

#### 受入基準

1. THE Approvals_Page SHALL support sorting by the following columns: qty(合計数量), date(起票日), delivery(納期), orderno(発注番号), itemname(品目名), price(単価), amount(金額), dest(発注書送付先)
2. WHEN a sort column header is clicked, THE Approvals_Page SHALL toggle between ascending and descending order
3. WHEN no explicit sort is specified, THE Approvals_Page SHALL apply default sort by OrderDate descending, then ItemName ascending
4. ~~WHEN no explicit sort is specified and StatusFilter≠30, THE Approvals_Page SHALL apply default sort by OrderDate ascending, then ItemName ascending~~ (廃止: 全ステータスで起票日降順に統一)
5. THE sort parameters (sort, desc) SHALL be preserved across pagination

### 要件 7: 発注番号カスタムソート

**ユーザーストーリー:** 承認担当者として、承認済一覧が発注番号の論理的な順序で表示されることで、日付・グループ・枝番の関係を把握しやすくしたい。

#### 受入基準

1. THE Approvals_Page SHALL parse OrderNo format `{prefix}-{date}-{group}-{seq}` (例: G201-260513-001-001)
2. THE date component SHALL be extracted from the second segment (index 1) of the hyphen-delimited OrderNo
3. THE group component SHALL be extracted as an integer from the third segment (index 2) of the hyphen-delimited OrderNo
4. THE seq component SHALL be extracted as an integer from the fourth segment (index 3) of the hyphen-delimited OrderNo
5. WHEN OrderNo is null or empty, THE extraction functions SHALL return empty string (date) or 0 (group, seq)

### 要件 8: ページネーション

**ユーザーストーリー:** 承認担当者として、大量の発注データをページ分割して表示できることで、画面の応答性を維持しつつ全件を確認したい。

#### 受入基準

1. THE Approvals_Page SHALL display orders in pages with a configurable page size (10, 20, 30, 50)
2. WHEN a user changes the page size, THE Approvals_Page SHALL persist the preference via `IUserPreferenceService.SetPageSizeAsync` with key "Approvals_Index"
3. THE Approvals_Page SHALL retrieve the user's saved page size via `IUserPreferenceService.GetPageSizeAsync` on page load
4. THE Approvals_Page SHALL display pagination controls (first, previous, page numbers, next, last) when TotalPages > 1
5. WHEN CurrentPage exceeds TotalPages, THE Approvals_Page SHALL adjust CurrentPage to TotalPages
6. THE pagination controls SHALL preserve sort parameters and StatusFilter

### 要件 9: Excelエクスポート

**ユーザーストーリー:** 承認担当者として、発注一覧をExcelファイルとしてダウンロードできることで、オフラインでの確認や報告資料の作成に活用したい。

#### 受入基準

1. THE Approvals_Page SHALL display an "Excel" export button
2. WHEN the Excel export is triggered, THE Approvals_Page SHALL generate an xlsx file containing all orders matching the current StatusFilter (pagination無視)
3. THE exported Excel file SHALL contain the following columns: No, 発注番号, 種別, 品目コード, 品目名, 数量, 単価, 金額(千円), 起票日, 納期, 発注書送付先, 倉庫名, 出力区分, 発注者, 承認日時, 承認者
4. THE exported file name SHALL follow the format "発注一覧_{statusName}_{yyyyMMdd}.xlsx" where statusName is 未承認/承認済/差戻し
5. THE Excel file SHALL have bold headers with light gray background
6. THE Excel columns SHALL be auto-adjusted to content width
7. THE 出力区分 column SHALL display: 0="エントリのみ", 1="印刷のみ", 2="FAXのみ", 3="印刷/FAX", other="-"

### 要件 10: PDF個別ダウンロード

**ユーザーストーリー:** 承認担当者として、個別の発注書をPDFでダウンロードできることで、印刷や取引先への送付に利用したい。

#### 受入基準

1. WHEN a PDF download is requested for a specific orderId, THE Approvals_Page SHALL call `IOrderPdfService.GenerateOrderPdfAsync(orderId)` to generate the PDF
2. THE Approvals_Page SHALL return the PDF file with content type "application/pdf"
3. THE PDF file name SHALL be "{orderNo}.pdf" where orderNo is retrieved via `IOrderPdfService.GetOrderNoAsync(orderId)`

### 要件 11: 認可制御

**ユーザーストーリー:** システム管理者として、承認ページへのアクセスが権限のあるユーザーに限定されることで、不正な承認操作を防止したい。

#### 受入基準

1. THE Approvals_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy

### 要件 12: 一覧表示列

**ユーザーストーリー:** 承認担当者として、発注の重要情報が一覧で確認できることで、承認判断に必要な情報を一目で把握したい。

#### 受入基準

1. WHEN StatusFilter=20, THE Approvals_Page SHALL display a checkbox column for row selection instead of a row number column
2. WHEN StatusFilter≠20, THE Approvals_Page SHALL display a sequential row number (No) column
3. WHEN StatusFilter=30, THE Approvals_Page SHALL display the 発注番号 column (sortable)
4. THE Approvals_Page SHALL always display the following columns: 種別, 品目コード, 品目名, 合計数量, 単価, 金額(千円), 起票日, 納期, 発注書送付先, 倉庫名, 発注者, 承認日時, 承認者
5. THE 種別 column SHALL display badges: "手動"(bg-primary), "仮発注"(bg-info), "自動"(bg-secondary)
6. WHEN no orders match the current filter, THE Approvals_Page SHALL display "該当する発注はありません。"
