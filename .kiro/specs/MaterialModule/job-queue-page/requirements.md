# 要件定義書

## はじめに

印刷キューページ（JobQueue/Index）の機能仕様。承認済み発注の印刷・FAX送信状況を発注番号グループ単位で一覧表示し、グループ単位でのPDFダウンロードを提供する画面。ステータスフィルタ、ページネーション、ソート機能を含む。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **JobQueue_Page**: MaterialModule/Areas/Material/Pages/JobQueue/Index に配置されたジョブキュー画面
- **OrderNoGroup**: 発注番号の先頭3セグメント（プラント-日付-グループ番号）によるグループキー（例: G201-260513-001）
- **JobQueueGroupItem**: グループ化された発注情報の表示モデル
- **IOrderPdfService**: 発注書PDF生成サービスインターフェース
- **IUserPreferenceService**: ユーザーごとのページサイズ設定を管理するサービス
- **t_order_reports**: 発注レポートテーブル（印刷・FAXステータス管理）
- **t_orders**: 発注テーブル
- **PrintStatus**: 印刷ステータス（0=対象外, 1=待機, 2=完了, 9=エラー）
- **FaxStatus**: FAXステータス（0=対象外, 1=待機, 2=完了, 9=エラー）
- **ReportType**: レポート種別（"order_approval" = 発注承認レポート）
- **PageSize**: 1ページあたりの表示件数（10, 20, 30, 50から選択）

## 要件

### 要件 1: グループ化された発注一覧表示

**ユーザーストーリー:** 購買担当者として、発注を送付先グループ単位で確認できることで、印刷・FAX送信の状況を効率的に管理したい。

#### 受入基準

1. THE JobQueue_Page SHALL display orders grouped by the first 3 segments of OrderNo (plant-date-group) extracted by splitting OrderNo on "-" delimiter
2. THE JobQueue_Page SHALL join t_order_reports with t_orders on ReferenceCode = OrderNo where ReportType = "order_approval"
3. THE JobQueue_Page SHALL filter orders by the current user's UserId (User.Identity.Name)
4. THE group display SHALL show the following columns: No(連番), 発注番号(グループキー), 送付先, 代表品目, 件数, 承認日時, 印刷, FAX, PDF
5. THE 代表品目 SHALL be the ItemName of the first order (sorted by OrderNo) in the group
6. THE 件数 SHALL be the count of orders within the group
7. THE 送付先 SHALL be the DestinationName of the first order in the group
8. THE 承認日時 SHALL be formatted as "yyyy-MM-dd HH:mm", displaying "-" when null
9. WHEN no data matches the current filter, THE JobQueue_Page SHALL display "該当するデータはありません。"
10. THE JobQueue_Page SHALL display the total count in the card header as "ジョブリスト（{count} 件）"

### 要件 2: ステータスフィルタ

**ユーザーストーリー:** 購買担当者として、印刷ステータスで絞り込めることで、未処理・完了・エラーのジョブを個別に確認したい。

#### 受入基準

1. THE JobQueue_Page SHALL display a status dropdown filter with options: 待機(1), 完了(2), エラー(9)
2. WHEN no StatusFilter is specified, THE JobQueue_Page SHALL default to 待機(1)
3. WHEN a StatusFilter value is selected, THE JobQueue_Page SHALL filter t_order_reports by PrintStatus matching the selected value
4. THE status dropdown SHALL auto-submit on change (onchange="this.form.submit()")
5. THE StatusFilter parameter SHALL support GET binding (SupportsGet = true)

### 要件 3: 印刷・FAXステータスバッジ表示

**ユーザーストーリー:** 購買担当者として、各グループの印刷・FAX状況がバッジで視覚的に表示されることで、処理状況を一目で把握したい。

#### 受入基準

1. THE 印刷 column SHALL display a badge with the following mapping: 0="対象外"(bg-secondary), 1="待機"(bg-warning text-dark), 2="完了"(bg-success), 9="エラー"(bg-danger)
2. THE FAX column SHALL display a badge with the following mapping: 0="対象外"(bg-secondary), 1="待機"(bg-warning text-dark), 2="完了"(bg-success), 9="エラー"(bg-danger)

### 要件 4: PDFダウンロード

**ユーザーストーリー:** 購買担当者として、グループ単位で発注書PDFをダウンロードできることで、印刷や送付に利用したい。

#### 受入基準

1. THE JobQueue_Page SHALL display a PDF download button (icon: bi-file-pdf) for each group row
2. WHEN the PDF button is clicked, THE JobQueue_Page SHALL call `IOrderPdfService.GenerateGroupOrderPdfAsync(orderNoGroup)` via GET handler
3. THE PDF SHALL be returned with content type "application/pdf"
4. THE PDF download SHALL use JavaScript fetch to download and save the file with filename "{orderNoGroup}.pdf"
5. IF the PDF generation fails, THEN THE JobQueue_Page SHALL display an alert with the error message "PDF生成に失敗しました" or the server error message

### 要件 5: ソート機能

**ユーザーストーリー:** 購買担当者として、一覧を任意の列で並べ替えられることで、確認したいジョブを素早く見つけたい。

#### 受入基準

1. THE JobQueue_Page SHALL support sorting by the following columns: orderno(発注番号), dest(送付先), item(代表品目), approved(承認日時)
2. WHEN a sort column header is clicked, THE JobQueue_Page SHALL toggle between ascending and descending order
3. WHEN no explicit sort is specified, THE JobQueue_Page SHALL apply default sort by ApprovedAt descending
4. THE sort parameters (sort, desc) SHALL be preserved across pagination and filter changes

### 要件 6: ページネーション

**ユーザーストーリー:** 購買担当者として、大量のジョブデータをページ分割して表示できることで、画面の応答性を維持しつつ全件を確認したい。

#### 受入基準

1. THE JobQueue_Page SHALL display groups in pages with a configurable page size (10, 20, 30, 50)
2. WHEN a user changes the page size, THE JobQueue_Page SHALL persist the preference via `IUserPreferenceService.SetPageSizeAsync` with key "JobQueue_Index"
3. THE JobQueue_Page SHALL retrieve the user's saved page size via `IUserPreferenceService.GetPageSizeAsync` on page load
4. THE JobQueue_Page SHALL display pagination controls (first, previous, page numbers, next, last) when TotalPages > 1
5. WHEN CurrentPage exceeds TotalPages, THE JobQueue_Page SHALL adjust CurrentPage to TotalPages
6. WHEN CurrentPage is less than 1, THE JobQueue_Page SHALL adjust CurrentPage to 1
7. THE pagination controls SHALL preserve StatusFilter parameter

### 要件 7: 発注番号グループキー抽出

**ユーザーストーリー:** システムとして、発注番号からグループキーを正しく抽出できることで、関連する発注を正確にグループ化したい。

#### 受入基準

1. THE JobQueue_Page SHALL extract the group key by splitting OrderNo on "-" and joining the first 3 segments
2. WHEN OrderNo is "G201-260513-001-001", THE extracted group key SHALL be "G201-260513-001"
3. WHEN OrderNo has fewer than 3 segments, THE group key SHALL be the original OrderNo

### 要件 8: 認可制御

**ユーザーストーリー:** システム管理者として、ジョブキューページへのアクセスが権限のあるユーザーに限定されることで、発注書の不正ダウンロードを防止したい。

#### 受入基準

1. THE JobQueue_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy
