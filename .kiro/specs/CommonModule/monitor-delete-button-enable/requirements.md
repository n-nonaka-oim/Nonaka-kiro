# Requirements Document

## Introduction

CommonModule の 2 つの監視ページ（プリント出力監視 `PrintMonitor/Index`・SMTP送信監視 `SmtpMonitor/Index`）に配置された「選択削除」ボタンは、現状ジョブ選択が 0 件でも常時活性のため、未選択のまま押下できる。押下時には既存の確認関数（`confirmPrintDelete()` / `confirmSmtpDelete()`）が 0 件を検知して中止するが、ボタン自体が押下可能である点は誤操作を招きやすい。

本機能は、両ページの「選択削除」ボタンを、ジョブ用チェックボックスの選択件数に応じて活性／非活性（`disabled`）に制御する。0 件のときは非活性、1 件以上のときは活性とする。既存の確認関数は多重防御として維持する。

変更範囲はクライアント側（各 `Index.cshtml` の削除ボタン属性および `@section Scripts` 内の JavaScript）に限定し、code-behind・削除処理（POST・`asp-page-handler=Delete`）・その他の列や機能・自動更新は変更しない。2 ページは対称的な仕様とする。

## Glossary

- **Print_Monitor_Page**: プリント出力監視ページ（`CommonModule/Areas/Common/Pages/PrintMonitor/Index.cshtml`）
- **Smtp_Monitor_Page**: SMTP送信監視ページ（`CommonModule/Areas/Common/Pages/SmtpMonitor/Index.cshtml`）
- **Monitor_Page**: Print_Monitor_Page および Smtp_Monitor_Page の総称
- **Delete_Button**: 各 Monitor_Page の「選択削除」ボタン（Print_Monitor_Page は `form="printDeleteForm"`、Smtp_Monitor_Page は `form="smtpDeleteForm"`）
- **Job_Checkbox**: 各行のジョブ選択チェックボックス（Print_Monitor_Page は class `print-job-check`、Smtp_Monitor_Page は class `smtp-job-check`）
- **Select_All_Checkbox**: 全選択チェックボックス（Print_Monitor_Page は id `printCheckAll`、Smtp_Monitor_Page は id `smtpCheckAll`）
- **Selected_Count**: 該当ページの Job_Checkbox のうちチェック状態のものの件数
- **Confirm_Function**: 削除押下時の既存確認関数（`confirmPrintDelete()` / `confirmSmtpDelete()`）。0 件で alert 表示・中止、1 件以上で確認ダイアログを表示する

## Requirements

### Requirement 1: 初期表示時のボタン活性制御

**User Story:** 監視ページの利用者として、ページ表示直後にジョブを 1 件も選択していないときは選択削除ボタンを押せない状態にしてほしい。未選択での誤操作を防ぐため。

#### Acceptance Criteria

1. WHEN Monitor_Page の初期表示（DOMContentLoaded）が完了し、かつ Selected_Count が 0 である、THE Monitor_Page SHALL Delete_Button を非活性（`disabled`）に設定する
2. WHEN Monitor_Page の初期表示（DOMContentLoaded）が完了し、かつ Selected_Count が 1 以上である、THE Monitor_Page SHALL Delete_Button を活性（`disabled` を解除）に設定する

### Requirement 2: 行チェックボックス変更時のボタン活性制御

**User Story:** 監視ページの利用者として、各行のチェックを付け外しするたびに選択削除ボタンの押下可否が選択状況に追従してほしい。現在の選択状況が一目でわかるため。

#### Acceptance Criteria

1. WHEN 利用者が Job_Checkbox のチェック状態を変更し、かつ変更後の Selected_Count が 1 以上である、THE Monitor_Page SHALL Delete_Button を活性に設定する
2. WHEN 利用者が Job_Checkbox のチェック状態を変更し、かつ変更後の Selected_Count が 0 である、THE Monitor_Page SHALL Delete_Button を非活性に設定する

### Requirement 3: 全選択チェックボックス操作時のボタン活性制御

**User Story:** 監視ページの利用者として、全選択チェックボックスで一括選択・一括解除したときも選択削除ボタンの押下可否が追従してほしい。一括操作時も選択状況と整合させるため。

#### Acceptance Criteria

1. WHEN 利用者が Select_All_Checkbox を操作し、かつ操作後の Selected_Count が 1 以上である、THE Monitor_Page SHALL Delete_Button を活性に設定する
2. WHEN 利用者が Select_All_Checkbox を操作し、かつ操作後の Selected_Count が 0 である、THE Monitor_Page SHALL Delete_Button を非活性に設定する

### Requirement 4: 既存の確認機能の維持（多重防御）

**User Story:** 監視ページの利用者として、削除ボタン押下時の確認ダイアログや未選択時の警告は従来どおり維持してほしい。誤削除を二重に防ぐため。

#### Acceptance Criteria

1. WHEN Delete_Button が押下される、THE Monitor_Page SHALL Confirm_Function を実行する
2. IF Delete_Button 押下時の Selected_Count が 0 である、THEN THE Monitor_Page SHALL alert により未選択を通知し、削除処理の送信を中止する
3. WHEN Delete_Button 押下時の Selected_Count が 1 以上である、THE Monitor_Page SHALL 確認ダイアログを表示し、承認された場合のみ削除処理を送信する

### Requirement 5: 変更範囲の限定と対称性

**User Story:** 開発保守担当者として、本変更が既存機能へ副作用を与えないよう、変更範囲をクライアント側に限定し 2 ページで同一の方式にしてほしい。既存の削除処理や自動更新を壊さないため。

#### Acceptance Criteria

1. THE Monitor_Page SHALL ボタン活性制御をクライアント側（`Index.cshtml` の Delete_Button 属性および `@section Scripts` 内 JavaScript）のみで実装する
2. THE Monitor_Page SHALL 削除処理（POST・`asp-page-handler=Delete`）、その他の列・機能、および自動更新（10秒）の挙動を変更前と同一に維持する
3. THE Print_Monitor_Page および Smtp_Monitor_Page SHALL 同一のボタン活性制御方式（初期表示・行チェック変更・全選択操作の 3 契機で Selected_Count に基づき活性状態を更新する）を適用する
