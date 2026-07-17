# Design Document

## Overview

原材料工場入請求画面（`MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml`）の未登録（pending）ビューにおける操作UIを整備する軽微な変更。主対象は **cshtml 内の JavaScript とラベル表示テキスト** である。加えて 2026/07/17 の後続整理で、R2（選択必須）をサーバ側でも担保するため code-behind（`Index.cshtml.cs`）の `OnPostSubmitAsync` から「未選択→全件」フォールバックを削除した（詳細は「Code-behind の扱い（2026/07/17 更新）」を参照）。

変更の骨子は以下3点。

- 請求ボタン（`btnSubmit`）の活性制御を削除ボタン（`btnRemove`）と完全統一する（選択0件で非活性、1件以上で活性、初期は非活性）。
- 請求送信関数（`submitEntries()`）の未選択時全件フォールバックを除去し、選択0件は早期リターンで送信しない。
- PDF 出力チェックボックスの **表示ラベルテキストのみ**「PDF出力」→「印刷」に変更する（id・送信プロパティ名・既定ON・分岐ロジックは不変）。

Bootstrap 5 + vanilla JS の既存構成を踏襲し、新規ライブラリ・CSSは追加しない。

## Scope（変更範囲）

| 対象 | 変更 | 内容 |
|---|---|---|
| `Areas/Material/Pages/Dispatches/Index.cshtml`（マークアップ） | あり | `btnSubmit` に `disabled` 既定付与、ラベルテキスト変更 |
| `Areas/Material/Pages/Dispatches/Index.cshtml`（`@section Scripts` 内 JS） | あり | `updateActionButtons()` に btnSubmit 制御追加、`submitEntries()` のフォールバック除去＋早期リターン |
| `Areas/Material/Pages/Dispatches/Index.cshtml.cs`（code-behind） | あり（2026/07/17 更新） | `OnPostSubmitAsync` の「未選択→全件」フォールバック削除、選択0件は `ErrorMessage`＋`ReloadAsync` で早期リターン。詳細は後述「Code-behind の扱い（2026/07/17 更新）」を参照。PDF/在庫減算/外部出力/選択時ロジックは不変 |
| pre-delivery ビュー / `clnCoCore`（MainWeb・AuthModule・SharedCore） | **なし** | 不変更 |

すべての変更は `StatusView == "pending"` 時に描画される要素・スクリプトに閉じている。pre-delivery ビューは `btnSubmit` / `chkPdfOutput` / `submitEntries()` を描画・使用しないため影響を受けない。

## Architecture

本変更の中心はクライアント側（ブラウザ）に閉じた表示・入力制御の調整である。サーバ側は R2 を担保する範囲のみに限定して変更する（`OnPostSubmitAsync` の未選択→全件フォールバック削除＝選択0件の早期リターン化）。DB・PDF生成・在庫減算・外部出力・選択時の登録ロジックには触れない。

```
[pending ビュー DOM]
   entry-check (チェックボックス群)
        │ change / 行クリック / selectAll
        ▼
   updateActionButtons()            ← ボタン活性 & hidden fields 更新
        ├─ btnRemove.disabled = (選択0件)
        └─ btnSubmit.disabled = (選択0件)   ★追加（btnRemove と同一基準）

[請求ボタン click]
        ▼
   submitEntries()
        ├─ 選択0件 → 早期リターン（送信しない）  ★フォールバック除去
        ├─ confirm('選択した N 件を登録しますか？')  （文言維持）
        └─ fetch(?handler=Submit)  formData: SelectedEntryIds[], PdfOutput
                │
                ▼
        [Index.cshtml.cs OnPostSubmitAsync]
             ├─ 選択0件 → ErrorMessage + ReloadAsync（早期リターン）★フォールバック削除
             └─ 選択1件以上 → PDF/在庫減算/外部出力（不変）
```

## Components and Interfaces

### 1. マークアップ変更（`btnSubmit`）

現状の `btnSubmit` には `disabled` 属性が無い。これを削除ボタンと同様に既定 disabled とする（R1.2）。

```html
<!-- 変更前 -->
<button type="button" class="btn btn-success btn-sm" id="btnSubmit" onclick="submitEntries();">
    <i class="bi bi-check-circle"></i> 請求
</button>

<!-- 変更後：disabled 既定を付与（btnRemove と同じ扱い） -->
<button type="button" class="btn btn-success btn-sm" id="btnSubmit" disabled onclick="submitEntries();">
    <i class="bi bi-check-circle"></i> 請求
</button>
```

### 2. マークアップ変更（ラベルテキスト）

`<label for="chkPdfOutput">` の **表示テキストのみ** 変更する。`chkPdfOutput` の id・`checked` 既定・class は不変（R3.2/R3.4）。

```html
<!-- 変更前 -->
<label for="chkPdfOutput" class="form-check-label small">PDF出力</label>

<!-- 変更後 -->
<label for="chkPdfOutput" class="form-check-label small">印刷</label>
```

### 3. JS 変更（`updateActionButtons()`）

`btnRemove` と同一基準で `btnSubmit.disabled` を制御する（R1.1/R1.3/R1.4/R1.5）。判定に用いる選択件数（`ids.length`）は `btnRemove` と同じ値を使い、基準を一元化する。

```javascript
function updateActionButtons() {
    var checked = document.querySelectorAll('.entry-check:checked');
    var ids = Array.from(checked).map(function(cb) { return cb.value; });

    var btnRemove = document.getElementById('btnRemove');
    var removeFields = document.getElementById('removeHiddenFields');
    if (btnRemove && removeFields) {
        btnRemove.disabled = ids.length === 0;
        removeFields.innerHTML = ids.map(function(id) {
            return '<input type="hidden" name="SelectedEntryIds" value="' + id + '" />';
        }).join('');
    }

    // btnRecover（既存・pre-delivery 用）は不変
    var btnRecover = document.getElementById('btnRecover');
    var recoverFields = document.getElementById('recoverHiddenFields');
    if (btnRecover && recoverFields) {
        btnRecover.disabled = ids.length === 0;
        recoverFields.innerHTML = ids.map(function(id) {
            return '<input type="hidden" name="SelectedEntryIds" value="' + id + '" />';
        }).join('');
    }

    // ★追加：請求ボタンを削除ボタンと同一基準で活性制御
    var btnSubmit = document.getElementById('btnSubmit');
    if (btnSubmit) {
        btnSubmit.disabled = ids.length === 0;
    }
}
```

`updateActionButtons()` は既存の `selectAll` change / 行クリック / `entry-check` change の各ハンドラから呼ばれており、選択件数の変化に追従する（R1.3/R1.4）。呼び出し箇所の追加・変更は不要。

### 4. JS 変更（`submitEntries()`）

未選択時に全チェックを付けて全件送信するフォールバックを除去し、選択0件は早期リターンする（R2.1/R2.2）。選択1件以上のときは選択分のみを送信（R2.3）。confirm 文言・`PdfOutput` の append は現状維持（R2.4/R3.3）。

```javascript
function submitEntries() {
    var checked = document.querySelectorAll('.entry-check:checked');
    var ids = Array.from(checked).map(function(cb) { return cb.value; });

    // ★変更：全件フォールバックを除去。選択0件は送信しない（早期リターン）
    if (ids.length === 0) {
        return;
    }

    if (!confirm('選択した ' + ids.length + ' 件を登録しますか？')) return;   // 文言維持

    var pdfOutput = document.getElementById('chkPdfOutput') && document.getElementById('chkPdfOutput').checked;
    var token = document.querySelector('input[name="__RequestVerificationToken"]').value;
    var formData = new FormData();
    ids.forEach(function(id) { formData.append('SelectedEntryIds', id); });
    formData.append('__RequestVerificationToken', token);
    formData.append('PdfOutput', pdfOutput ? 'true' : 'false');   // プロパティ名・分岐は不変

    // 以降（fetch → PDF ダウンロード / reload）は現状のまま
    window.MaterialLock.lock('出庫登録中...');
    fetch(pageUrl + '?handler=Submit', { method: 'POST', body: formData })
        .then(function(response) { /* 現状維持 */ })
        .catch(function() { window.MaterialLock.unlock(); location.reload(); });
}
```

備考: 請求ボタン自体が選択0件時 disabled になる（コンポーネント1・3）ため、選択0件で `submitEntries()` が呼ばれる経路は通常発生しない。R2（選択必須）は **クライアント（`submitEntries()` 早期リターン）とサーバ（`OnPostSubmitAsync` 選択必須化）の二重で担保** する。クライアント早期リターンが第一防御、サーバ側の選択0件早期リターン（`ErrorMessage`＋`ReloadAsync`）が最終防御として機能する（詳細は「Code-behind の扱い（2026/07/17 更新）」参照）。

## Code-behind の扱い（2026/07/17 更新）

### 当初方針（参考・履歴）

当初 design では code-behind（`Index.cshtml.cs`）を **不変更** とする方針だった。根拠は次のとおり: `OnPostSubmitAsync` には `SelectedEntryIds.Count == 0` のとき全件を対象とするサーバ側フォールバックが存在するが、クライアント側で早期リターンを行う結果、UI から `SelectedEntryIds` が空で送信される経路が消滅するため、サーバ側フォールバックは UI 到達不能な経路であり実害がない、というものだった。

### 現行方針（2026/07/17 後続整理で変更）

2026/07/17 の後続整理で、R2（選択必須）を **クライアント側だけでなくサーバ側でも厳密に担保する** 方針に変更した。これにより `OnPostSubmitAsync` の「未選択（`SelectedEntryIds.Count == 0`）→全件対象」フォールバックを **削除** し、選択0件のときは `ErrorMessage` を設定したうえで `ReloadAsync`（一覧再読込）して **早期リターン** する実装に変更した。

- **変更箇所**: `OnPostSubmitAsync` の「未選択→全件」フォールバックを削除し、選択0件は `ErrorMessage` ＋ `ReloadAsync` で早期リターン。
- **不変箇所**: `PdfOutput` による分岐（PDF 出力(i)／リダイレクト）、在庫減算、外部出力(ii)、選択時（`SelectedEntryIds.Count >= 1`）の登録ロジックはいずれも従来どおり不変（R3.5）。
- **理由**: UI 早期リターンに依存せず、サーバ側単体でも「選択0件で全件処理されない」ことを保証し、R2 を UI・サーバの二重で担保する（防御の多層化）。

この変更は **MaterialModule 配下（`Index.cshtml.cs`）に閉じており**、`clnCoCore`（MainWeb / AuthModule / SharedCore）には一切変更を加えない（R4.3）。

## Data Models

データモデルの変更はない。送信ペイロード（`SelectedEntryIds[]`・`PdfOutput`・`__RequestVerificationToken`）は現状のまま維持する。

## Error Handling

- 選択0件での請求: `submitEntries()` の早期リターンにより送信されない。加えて `btnSubmit` が disabled のため click 自体が発生しない（多重防御）。万一サーバに空の `SelectedEntryIds` が到達しても、`OnPostSubmitAsync` が `ErrorMessage`＋`ReloadAsync` で早期リターンし全件処理は行わない（サーバ側担保）。
- confirm キャンセル: 現状どおり送信を中断（`return`）。
- fetch 失敗: 現状どおり `catch` で `MaterialLock.unlock()` 後に `location.reload()`。
- 既存のトークン取得・PDF ダウンロード分岐は不変のため、エラー挙動に回帰は生じない。

## Testing Strategy

本変更はクライアント側の DOM 状態制御・ラベル表示であり、大半は静的な具体検証（EXAMPLE）と非改変の回帰確認（SMOKE）で足りる。状態関数の普遍条件のみプロパティ化する。

- **Unit / Example テスト**: 初期 disabled 属性、ラベル文言「印刷」、id/checked 維持、confirm 文言、選択0件での非送信、`PdfOutput` キー append。
- **Property テスト**: 下記 Correctness Properties（`updateActionButtons()` の状態不変条件、送信対象＝選択集合）。JSDOM 等で `entry-check` の checked 集合を生成入力とし、最低100イテレーションで検証する。
- **回帰確認**: pre-delivery ビューの表示・挙動、`PdfOutput` true/false の分岐。
- テスト実行環境が JS 側に無い場合は、レビューによる差分確認と手動動作確認（選択件数変化に応じたボタン活性、選択分のみ請求、ラベル表示）を最低限の検証とする。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 請求ボタンの活性状態は選択件数に一致する

*For any* pending ビューの `entry-check` チェック集合（0件〜全件の任意の部分集合）について、`updateActionButtons()` 実行後の `btnSubmit.disabled` は「選択件数が0であること（`checkedCount === 0`）」と常に一致する。

**Validates: Requirements 1.1, 1.3, 1.4**

### Property 2: 請求ボタンと削除ボタンの活性基準は同一である

*For any* `entry-check` チェック集合について、`updateActionButtons()` 実行後の `btnSubmit.disabled` は同一時点の `btnRemove.disabled` と常に等しい。

**Validates: Requirements 1.5**

### Property 3: 請求送信対象は選択されたエントリ集合と一致する

*For any* 非空の `entry-check` チェック集合について、`submitEntries()` が送信する `SelectedEntryIds` の集合は選択されたチェックボックスの value 集合と過不足なく一致し、非選択エントリを含まない（かつ選択0件のときは一切送信しない）。

**Validates: Requirements 2.1, 2.2, 2.3**
