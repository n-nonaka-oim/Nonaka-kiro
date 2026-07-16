# Requirements Document

## Introduction

原材料工場入請求画面（MaterialModule / `Areas/Material/Pages/Dispatches/Index.cshtml`）の未登録（pending）ビューにおける操作UIを整備する。請求ボタン（btnSubmit）の活性化挙動を削除ボタン（btnRemove）と完全統一し、選択必須とする。あわせて PDF 出力チェックボックスの表示ラベルのみを「印刷」に変更する。機能ロジック（PdfOutput による分岐）・プロパティ名・既定値・確認ダイアログ文言は現状維持とし、変更は pending ビューに限定する。clnCoCore（MainWeb / AuthModule / SharedCore 等）は変更しない。

## Glossary

- **Dispatches_Index_Page**: `MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml`（および `Index.cshtml.cs`）で構成される原材料工場入請求画面。
- **Pending_View**: `StatusView == "pending"`（未登録）のときに表示されるエントリリストビュー。
- **Submit_Button**: 請求ボタン。`id="btnSubmit"`。
- **Remove_Button**: 削除ボタン。`id="btnRemove"`。既存の活性化挙動（0件で非活性・1件以上で活性）の基準実装。
- **Entry_Checkbox**: 各エントリ行の選択チェックボックス。`class="entry-check"`。
- **Update_Action_Buttons**: 選択件数に応じてボタンの活性状態と hidden フィールドを更新する JavaScript 関数 `updateActionButtons()`。
- **Submit_Entries**: 請求送信処理を行う JavaScript 関数 `submitEntries()`。
- **Pdf_Output_Checkbox**: PDF 出力チェックボックス。`id="chkPdfOutput"`、送信プロパティ名 `PdfOutput`、既定 checked（ON）。
- **Pdf_Output_Label**: `Pdf_Output_Checkbox` に対応する `<label for="chkPdfOutput">` の表示テキスト。

## Requirements

### Requirement 1: 請求ボタンの活性化を削除ボタンと統一

**User Story:** 資材担当者として、請求ボタンの活性化挙動を削除ボタンと同一にしてほしい。そうすれば操作の一貫性が保たれ、誤操作を防げる。

#### Acceptance Criteria

1. WHILE `Pending_View` が表示されていて選択された `Entry_Checkbox` が0件である間、THE `Dispatches_Index_Page` SHALL `Submit_Button` を非活性（disabled）状態で表示する。
2. THE `Dispatches_Index_Page` SHALL `Submit_Button` を初期表示時に非活性（disabled）状態とする。
3. WHEN 選択された `Entry_Checkbox` が1件以上に変化したとき、THE `Update_Action_Buttons` SHALL `Submit_Button` を活性（enabled）状態にする。
4. WHEN 選択された `Entry_Checkbox` が0件に変化したとき、THE `Update_Action_Buttons` SHALL `Submit_Button` を非活性（disabled）状態にする。
5. THE `Update_Action_Buttons` SHALL `Submit_Button` の活性判定基準を `Remove_Button` の活性判定基準（選択件数0で非活性・1件以上で活性）と同一とする。

### Requirement 2: 請求時の選択必須化

**User Story:** 資材担当者として、請求時は対象エントリを明示的に選択させてほしい。そうすれば意図しない全件請求を防げる。

#### Acceptance Criteria

1. IF 選択された `Entry_Checkbox` が0件の状態で `Submit_Entries` が呼び出された、THEN THE `Dispatches_Index_Page` SHALL 請求送信処理を行わない。
2. THE `Submit_Entries` SHALL 選択された `Entry_Checkbox` が0件のときに全エントリを対象とするフォールバック処理を持たない。
3. WHEN 選択された `Entry_Checkbox` が1件以上の状態で `Submit_Entries` が呼び出されたとき、THE `Submit_Entries` SHALL 選択された `Entry_Checkbox` のみを請求対象とする。
4. THE `Submit_Entries` SHALL 請求送信前の確認ダイアログ文言を現状（`選択した {件数} 件を登録しますか？`）のまま維持する。

### Requirement 3: PDF出力ラベルの表示テキスト変更

**User Story:** 資材担当者として、チェックボックスのラベル表示を「印刷」にしてほしい。そうすれば実際の用途が直感的に理解できる。

#### Acceptance Criteria

1. THE `Pdf_Output_Label` SHALL 表示テキストを「印刷」とする。
2. THE `Pdf_Output_Checkbox` SHALL 要素 id を `chkPdfOutput` のまま維持する。
3. THE `Pdf_Output_Checkbox` SHALL 送信プロパティ名を `PdfOutput` のまま維持する。
4. THE `Pdf_Output_Checkbox` SHALL 初期状態を checked（ON）のまま維持する。
5. THE `Dispatches_Index_Page` SHALL `PdfOutput` の値による PDF 出力分岐処理を現状のまま維持する。

### Requirement 4: 変更範囲の限定

**User Story:** 開発担当者として、変更範囲を限定してほしい。そうすれば他ビューやモジュールへの影響を防げる。

#### Acceptance Criteria

1. THE `Dispatches_Index_Page` SHALL 本仕様による変更を `Pending_View` に限定する。
2. THE `Dispatches_Index_Page` SHALL pre-delivery ビューの表示および挙動を現状のまま維持する。
3. THE `Dispatches_Index_Page` SHALL clnCoCore（MainWeb / AuthModule / SharedCore 等）のソースおよび設定を変更しない。
