# Design Document

## Overview

CommonModule の 2 つの監視ページ（`PrintMonitor/Index.cshtml`・`SmtpMonitor/Index.cshtml`）の「選択削除」ボタンを、ジョブ選択件数に応じて活性／非活性（`disabled`）制御する。

- 0 件選択時: ボタンを `disabled`（押下不可）
- 1 件以上選択時: ボタンを活性（`disabled` 解除）

変更はクライアント側のみ（各 `Index.cshtml` の削除ボタン属性 + `@section Scripts` 内 JavaScript）。code-behind、削除 POST（`asp-page-handler=Delete`）、再出力／再送、フィルタ、ページャ、自動更新（10 秒）、既存の確認関数（`confirmPrintDelete()` / `confirmSmtpDelete()`）は一切変更しない。2 ページは対称的に実装する。

本設計は `CommonModule` 内で完結する。`clnCoCore`（MainWeb / AuthModule / SharedCore 等）には手を入れない。

## Architecture

```
[ページ表示]
   └─ DOMContentLoaded
        ├─ 既存: ツールチップ有効化
        ├─ 既存: 全選択トグル登録（checkAll.change）── ★直後に updateXxxDeleteButton() 呼び出しを追加
        ├─ 追加: 各行 Job_Checkbox に change リスナ登録 → updateXxxDeleteButton()
        └─ 追加: 初期状態の同期 updateXxxDeleteButton()

[活性更新関数] updateXxxDeleteButton()
   selectedCount = document.querySelectorAll('.xxx-job-check:checked').length
   btn.disabled = (selectedCount === 0)

[ボタン押下時（不変）]
   onclick="return confirmXxxDelete();"  ── 多重防御（0 件で alert・中止 / 1 件以上で確認ダイアログ）
```

活性状態は「選択件数の変化契機」でのみ更新される純粋なクライアント側 UI 制御であり、サーバ状態やネットワークに依存しない。

## Components and Interfaces

### 1. Delete_Button（マークアップ変更）

両ページの削除ボタンに `id` と初期 `disabled` を付与する。初期表示時は選択 0 件のため `disabled` を既定とし、DOMContentLoaded の `update` 呼び出しで実データに同期する（JS 無効環境でも「押せてしまう」ことを避けるため既定を `disabled` にする）。

Print_Monitor_Page:
```html
<button type="submit" form="printDeleteForm" id="btnPrintDelete" disabled
        class="btn btn-outline-danger btn-sm py-0 px-2"
        onclick="return confirmPrintDelete();" data-bs-toggle="tooltip"
        title="選択したジョブを削除（処理中は削除できません）">
    <i class="bi bi-trash"></i> 選択削除
</button>
```

Smtp_Monitor_Page:
```html
<button type="submit" form="smtpDeleteForm" id="btnSmtpDelete" disabled
        class="btn btn-outline-danger btn-sm py-0 px-2"
        onclick="return confirmSmtpDelete();" data-bs-toggle="tooltip"
        title="選択したジョブを削除（処理中は削除できません）">
    <i class="bi bi-trash"></i> 選択削除
</button>
```

`onclick`（多重防御）と `form` 属性はそのまま維持する。

### 2. 活性更新関数（`@section Scripts` に追加）

選択件数を数え `disabled` を切り替える純粋関数的な UI 更新関数。

Print_Monitor_Page:
```javascript
// 選択件数に応じて削除ボタンの活性/非活性を更新
function updatePrintDeleteButton() {
    var btn = document.getElementById('btnPrintDelete');
    if (!btn) return;
    var selectedCount = document.querySelectorAll('.print-job-check:checked').length;
    btn.disabled = (selectedCount === 0);
}
```

Smtp_Monitor_Page:
```javascript
// 選択件数に応じて削除ボタンの活性/非活性を更新
function updateSmtpDeleteButton() {
    var btn = document.getElementById('btnSmtpDelete');
    if (!btn) return;
    var selectedCount = document.querySelectorAll('.smtp-job-check:checked').length;
    btn.disabled = (selectedCount === 0);
}
```

### 3. 呼び出し契機（既存 DOMContentLoaded ブロックへ統合）

3 つの契機で `update` を呼ぶ。既存コードへの統合ポイントは以下。

Print_Monitor_Page（`smtp` は対称）:
```javascript
document.addEventListener('DOMContentLoaded', function () {
    // 既存: ツールチップ有効化（変更なし）
    var triggers = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    triggers.forEach(function (el) { new bootstrap.Tooltip(el); });

    // 全選択/全解除（既存トグル処理の直後に update 呼び出しを追加）
    var checkAll = document.getElementById('printCheckAll');
    if (checkAll) {
        checkAll.addEventListener('change', function () {
            document.querySelectorAll('.print-job-check').forEach(function (c) { c.checked = checkAll.checked; });
            updatePrintDeleteButton();          // ★追加（契機3: 全選択操作）
        });
    }

    // ★追加（契機2: 各行チェック変更）
    document.querySelectorAll('.print-job-check').forEach(function (c) {
        c.addEventListener('change', updatePrintDeleteButton);
    });

    // ★追加（契機1: 初期表示の同期）
    updatePrintDeleteButton();

    // 既存: 自動更新（10秒）ブロックは変更なし
    // ...
});
```

契機 1（初期同期）は `disabled` 既定を実データに合わせる保険。自動更新でリロードされても DOMContentLoaded が再走するため状態は再同期される。

## Data Models

新規データモデルなし。UI 状態のみ:

| 概念 | 由来 | 型 |
|------|------|----|
| Selected_Count | `document.querySelectorAll('.{print\|smtp}-job-check:checked').length` | number |
| Delete_Button.disabled | Selected_Count === 0 | boolean |

処理中ジョブ（PrintStatus/Status === 2）は行にチェックボックス自体を描画しないため、Selected_Count の対象外（既存仕様のまま）。

## Error Handling

- 削除ボタン要素が存在しない場合（`getElementById` が null）は `update` 関数で早期 return し、例外を出さない。
- Job_Checkbox が 0 個（該当ジョブなし）の場合、`querySelectorAll(...).length` は 0 となりボタンは `disabled` のまま。正しい挙動。
- JavaScript が無効な環境では `disabled` 既定が維持され、押下できない（安全側に倒れる）。
- ボタン活性はあくまで UI 補助であり、実際の 0 件送信防止は既存 `confirmXxxDelete()`（多重防御）が担う。両者は独立に機能する。

## Correctness Properties

本機能は静的な UI 制御（`querySelectorAll(...:checked).length === 0` による `disabled` 切替）であり、入力に応じて挙動が意味的に変化する純粋関数ロジックや、パーサ／シリアライザのような普遍的性質を持たない。判定は Bootstrap5 + vanilla JS による DOM 操作で、外部サービス・データ変換・アルゴリズムを含まない。

したがって Property-Based Testing（PBT）の対象外とする（ワークフローの「When PBT Is NOT Appropriate: UI rendering and layout」に該当）。

検証方法は以下とする:
- **差分レビュー**: 変更が 2 ページのマークアップ属性（`id` / `disabled`）と `@section Scripts` 内の追加関数・リスナに限定され、code-behind・削除 POST・自動更新・確認関数が不変であることをレビューで確認する。
- **手動確認**（両ページ対称）:
  1. 初期表示（選択 0 件）で削除ボタンが非活性であること（Req 1.1）
  2. 行チェックを 1 件付けると活性になり、外して 0 件に戻すと非活性になること（Req 2.1 / 2.2）
  3. 全選択で活性、全解除で非活性になること（Req 3.1 / 3.2）
  4. 削除ボタン押下時の確認ダイアログ・未選択警告が従来どおり動作すること（Req 4.1〜4.3）
  5. 削除処理・フィルタ・ページャ・自動更新（10 秒）が変更前と同一に動作すること（Req 5.2）
