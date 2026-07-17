# Implementation Plan: monitor-delete-button-enable

## Overview

CommonModule の 2 つの監視ページ（`PrintMonitor/Index.cshtml`・`SmtpMonitor/Index.cshtml`）の「選択削除」ボタンを、ジョブ選択件数に応じて活性／非活性（`disabled`）制御する。変更はクライアント側のみ（削除ボタン属性 + `@section Scripts` 内 JavaScript）。code-behind・削除 POST・自動更新・既存の確認関数は変更しない。2 ページは対称・独立に実装する。

実装はページ単位に分割し、各ページで「マークアップ属性付与」→「スクリプト追加」の順に段階実施する。編集は `str_replace` / `fs_write` のみで行い、`clnCoCore`（MainWeb / AuthModule / SharedCore 等）には一切手を入れない。design に Correctness Properties が無い静的 UI 制御のため、PBT タスクは設けず、差分レビューと手動確認で検証する。

## Tasks

- [ ] 1. PrintMonitor 削除ボタンの活性制御を実装
  - [ ] 1.1 削除ボタンに `id` と初期 `disabled` を付与
    - `CommonModule/Areas/Common/Pages/PrintMonitor/Index.cshtml` の「選択削除」ボタン（`form="printDeleteForm"`）に `id="btnPrintDelete"` と `disabled` 属性を追加
    - `onclick="return confirmPrintDelete();"` と `form` 属性はそのまま維持（多重防御・送信先を変更しない）
    - JS 無効環境でも押下できないよう初期値は `disabled`
    - _Requirements: 1.1, 4.1, 5.1_

  - [ ] 1.2 `@section Scripts` に活性更新関数と 3 契機の呼び出しを追加
    - `updatePrintDeleteButton()` を追加：`document.querySelectorAll('.print-job-check:checked').length === 0` で `btnPrintDelete.disabled` を切替、ボタン不在時は早期 return
    - 契機1（初期同期）：既存 `DOMContentLoaded` 内で `updatePrintDeleteButton()` を呼び出し、`disabled` 既定を実データに同期
    - 契機2（各行変更）：`.print-job-check` 各要素に `change` リスナを登録して `updatePrintDeleteButton()` を呼び出し
    - 契機3（全選択操作）：既存 `printCheckAll` の `change` トグル処理の直後に `updatePrintDeleteButton()` を呼び出し
    - 既存のツールチップ有効化・自動更新（10秒）ブロックは変更しない
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2, 5.1, 5.2_

- [ ] 2. SmtpMonitor 削除ボタンの活性制御を実装（PrintMonitor と対称）
  - [ ] 2.1 削除ボタンに `id` と初期 `disabled` を付与
    - `CommonModule/Areas/Common/Pages/SmtpMonitor/Index.cshtml` の「選択削除」ボタン（`form="smtpDeleteForm"`）に `id="btnSmtpDelete"` と `disabled` 属性を追加
    - `onclick="return confirmSmtpDelete();"` と `form` 属性はそのまま維持
    - JS 無効環境でも押下できないよう初期値は `disabled`
    - _Requirements: 1.1, 4.1, 5.1, 5.3_

  - [ ] 2.2 `@section Scripts` に活性更新関数と 3 契機の呼び出しを追加
    - `updateSmtpDeleteButton()` を追加：`document.querySelectorAll('.smtp-job-check:checked').length === 0` で `btnSmtpDelete.disabled` を切替、ボタン不在時は早期 return
    - 契機1（初期同期）：既存 `DOMContentLoaded` 内で `updateSmtpDeleteButton()` を呼び出し
    - 契機2（各行変更）：`.smtp-job-check` 各要素に `change` リスナを登録して `updateSmtpDeleteButton()` を呼び出し
    - 契機3（全選択操作）：既存 `smtpCheckAll` の `change` トグル処理の直後に `updateSmtpDeleteButton()` を呼び出し
    - 既存のツールチップ有効化・自動更新（10秒）ブロックは変更しない
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2, 5.1, 5.2, 5.3_

- [ ] 3. Checkpoint - 差分レビューと手動確認（ユーザー確認）
  - 差分レビュー：変更が 2 ページのマークアップ属性（`id` / `disabled`）と `@section Scripts` 内の追加関数・リスナに限定され、code-behind・削除 POST・自動更新（10秒）・確認関数が不変であることを確認（Req 5.1, 5.2）
  - `clnCoCore`（MainWeb / AuthModule / SharedCore 等）に差分が混入していないことを確認
  - 手動確認（両ページ対称）：初期表示（0件）で非活性（Req 1.1）／1件以上で活性・0件で非活性（Req 2.1, 2.2, 3.1, 3.2）／削除押下時の確認ダイアログ・未選択警告が従来どおり動作（Req 4.1〜4.3）
  - ビルドはユーザー側で実施。Ensure all tests pass, ask the user if questions arise.

## Notes

- 本 spec は静的 UI 制御で design に Correctness Properties が無いため、Property-Based Test タスクは設けない（検証は差分レビュー＋手動確認）。
- 編集は `str_replace` / `fs_write` のみを使用し、`clnCoCore` 配下は読み取り参照のみ（改変禁止）。
- 各タスクは要件へのトレーサビリティを持つ。2 ページは対称・独立のため並列実行可能。
- 同一ファイルを編集する 1.1→1.2、2.1→2.2 は競合回避のため別 wave に配置する。
- ビルド確認はユーザー側で実施する（Kiro からは実行しない）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "2.2"] }
  ]
}
```
