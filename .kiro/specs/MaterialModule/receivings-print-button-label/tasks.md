# Implementation Plan: receivings-print-button-label

## Overview

入庫管理画面（`MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml`）の PDF 出力ボタンのラベルを「入庫伝票」→「印刷」に変更する。変更はボタン要素内のテキストノード1箇所のみ。`str_replace` で `<i class="bi bi-file-pdf"></i> 入庫伝票` を文脈として一意に特定し、`入庫伝票` のみを `印刷` に置換する。JS 内 `fileName` の `'入庫伝票_'`・`onclick`・`class`・アイコン・`disabled` 制御式・code-behind は不変。静的ラベル変更のため PBT 対象なし（design 準拠）。

## Tasks

- [ ] 1. PDF出力ボタンのラベルを「印刷」に変更
  - [ ] 1.1 `Receivings/Index.cshtml` のボタンテキストを置換
    - 対象ファイル: `MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml`
    - `str_replace` で `<i class="bi bi-file-pdf"></i> 入庫伝票` を対象文脈に特定し、テキスト「入庫伝票」→「印刷」に置換する
    - `type` / `class`（`btn btn-outline-danger btn-sm text-nowrap`）/ `onclick="downloadReceivingPdf()"` / `disabled` 制御式 / アイコン `<i class="bi bi-file-pdf"></i>` は不変
    - JS 内 `fileName` の `'入庫伝票_...'` は誤置換しないこと（別行・別文脈）
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ]* 1.2 差分レビュー（目視確認）
    - 変更差分が当該ボタンのテキスト1点のみであることを確認
    - JS 内 `fileName`（`入庫伝票_yyyyMMdd_yyyyMMdd.pdf`）・code-behind `OnGetExportPdfAsync`・他ボタン・他要素に差分が無いことを確認
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 2. Checkpoint - ビルド確認（ユーザー実施）
  - ユーザー側でビルドを実行し、エラーが無いことを確認する（Kiro からはビルドを実行しない）
  - 問題があればユーザーに確認する

## Notes

- タスク `*` は任意（静的ラベル変更のため差分レビューは目視で担保）。
- design の Correctness Properties セクションは「PBT 対象無し」と結論しているため、プロパティテストタスクは含めない。
- ビルドはユーザー側で実施（プロジェクトルール準拠）。PowerShell によるファイル書き込みは禁止。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] }
  ]
}
```
