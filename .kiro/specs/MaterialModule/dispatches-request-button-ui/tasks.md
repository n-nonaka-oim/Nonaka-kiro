# Implementation Plan: 原材料工場入請求画面 操作UI整備（pending ビュー）

## Overview

対象は `MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml` の **pending ビュー内マークアップと `@section Scripts` 内 JavaScript のみ**。code-behind（`Index.cshtml.cs`）・pre-delivery ビュー・clnCoCore は変更しない。

各タスクは「1タスク＝単独で検証可能な最小変更」に分解する。すべての変更は `str_replace` / `fs_write` で行い、PowerShell でのファイル書き込みは行わない。ビルドは Kiro からは実行せず、最後にユーザー実施のビルド確認チェックポイントを置く。

実装言語: C# / ASP.NET Core Razor Pages（cshtml + vanilla JavaScript）。

## Tasks

- [x] 1. マークアップ変更（pending ビュー）
  - [x] 1.1 `btnSubmit` に `disabled` 既定を付与
    - `Areas/Material/Pages/Dispatches/Index.cshtml` の pending ビュー内 `<button id="btnSubmit" ...>` に `disabled` 属性を追加し、初期表示を非活性とする（`btnRemove` と同じ扱い）
    - id・class・`onclick="submitEntries();"`・アイコン・ラベル「請求」は不変
    - _Requirements: 1.2_

  - [x] 1.2 PDF出力ラベルの表示テキストを「印刷」に変更
    - `<label for="chkPdfOutput" ...>` の表示テキストのみ「PDF出力」→「印刷」に変更
    - `chkPdfOutput` の id・`checked` 既定・class・送信プロパティ名 `PdfOutput` は不変
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 2. JavaScript 変更（`@section Scripts` 内）
  - [x] 2.1 `updateActionButtons()` に `btnSubmit` の活性制御を追加
    - 既存の選択件数（`ids.length`）を用い、`btnRemove` と同一基準で `btnSubmit.disabled = ids.length === 0` を設定する
    - `btnRemove` / `btnRecover` の既存処理・hidden fields 更新は不変。呼び出し箇所（selectAll change / 行クリック / entry-check change）は追加変更なし
    - _Requirements: 1.1, 1.3, 1.4, 1.5_

  - [ ]* 2.2 `updateActionButtons()` のプロパティテスト（請求ボタン活性＝選択件数一致）
    - **Property 1: 請求ボタンの活性状態は選択件数に一致する**
    - **Validates: Requirements 1.1, 1.3, 1.4**
    - JSDOM 等で `entry-check` の checked 集合（0件〜全件の任意部分集合）を生成入力とし、実行後 `btnSubmit.disabled === (checkedCount === 0)` を最低100イテレーションで検証

  - [ ]* 2.3 `updateActionButtons()` のプロパティテスト（請求・削除ボタンの基準同一）
    - **Property 2: 請求ボタンと削除ボタンの活性基準は同一である**
    - **Validates: Requirements 1.5**
    - 任意の checked 集合について実行後 `btnSubmit.disabled === btnRemove.disabled` を検証

  - [x] 2.4 `submitEntries()` の未選択時全件フォールバック除去＋早期リターン
    - 選択0件時に全チェックを付けて全件送信するフォールバックを除去し、`ids.length === 0` で早期リターン（送信しない）
    - 選択1件以上のときは選択分のみ `SelectedEntryIds` に append。confirm 文言 `選択した N 件を登録しますか？`・`PdfOutput` の append・fetch 以降の処理は不変
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.3, 3.5_

  - [ ]* 2.5 `submitEntries()` のプロパティテスト（送信対象＝選択集合）
    - **Property 3: 請求送信対象は選択されたエントリ集合と一致する**
    - **Validates: Requirements 2.1, 2.2, 2.3**
    - 非空 checked 集合で送信 `SelectedEntryIds` が選択 value 集合と過不足なく一致し、選択0件では一切送信しないことを検証

  - [ ]* 2.6 表示・非改変の Example / 回帰テスト
    - `btnSubmit` の初期 `disabled` 属性、ラベル文言「印刷」、`chkPdfOutput` の id/checked 維持、confirm 文言維持、`PdfOutput` キー append を静的検証
    - pre-delivery ビューの表示・挙動、`PdfOutput` true/false の分岐が不変であることを回帰確認
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2_

- [~] 3. 最終チェックポイント - ビルド確認（ユーザー実施）
  - ユーザーにビルド（`MaterialModule` / ソリューション）を依頼し、`Areas/Material/Pages/Dispatches/Index.cshtml` の変更でビルドが通ることを確認する。Kiro からはビルドを実行しない
  - clnCoCore（MainWeb / AuthModule / SharedCore）および pre-delivery ビューに差分が混入していないことを確認する
  - 疑問が生じた場合はユーザーに確認する
  - _Requirements: 4.1, 4.2, 4.3_

## Notes

- `*` 付きサブタスクは任意（テスト）。JS 側のテスト実行環境が無い場合はレビュー差分確認＋手動動作確認（選択件数変化に応じたボタン活性、選択分のみ請求、ラベル表示）を最低限の検証とする
- すべての変更は単一ファイル `Index.cshtml` に閉じるため、各コード変更タスクは順に1つずつ実施し、完了ごとに内容を提示する
- code-behind（`Index.cshtml.cs`）のサーバ側フォールバックは本仕様では不変更（UI 早期リターンにより到達不能。将来整理は別タスク）
- ファイル書き込みは `str_replace` / `fs_write` のみ。PowerShell での書き込みは行わない

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["2.4"] },
    { "id": 5, "tasks": ["2.5", "2.6"] }
  ]
}
```
