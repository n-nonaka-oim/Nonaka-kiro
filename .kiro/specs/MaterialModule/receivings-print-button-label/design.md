# Design Document

## Overview

入庫管理画面（`MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml`）の PDF 出力ボタンの表示ラベルを「入庫伝票」から「印刷」へ変更する。変更は当該ボタン要素内のテキストノード1箇所のみを対象とし、ボタンの機能・属性・活性制御、および PDF 生成に関わる一切の処理（JavaScript の `downloadReceivingPdf()`、ダウンロードファイル名、code-behind `OnGetExportPdfAsync`、PDF 内容）は現状維持とする。

軽微な表示文言変更であり、新規コンポーネント・データモデル・サービスの追加は行わない。

## Scope

### 変更対象（1ファイル・1箇所）

- ファイル: `MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml`
- 対象: PDF 出力ボタン内のテキストノード

現状:

```razor
<button type="button" class="btn btn-outline-danger btn-sm text-nowrap" onclick="downloadReceivingPdf()" @(Model.TotalCount == 0 ? "disabled" : "")>
    <i class="bi bi-file-pdf"></i> 入庫伝票
</button>
```

変更後:

```razor
<button type="button" class="btn btn-outline-danger btn-sm text-nowrap" onclick="downloadReceivingPdf()" @(Model.TotalCount == 0 ? "disabled" : "")>
    <i class="bi bi-file-pdf"></i> 印刷
</button>
```

変更差分は `<i class="bi bi-file-pdf"></i> ` 直後のテキスト「入庫伝票」→「印刷」の1点のみ。`type` / `class` / `onclick` / `disabled` 制御式 / アイコン要素 (`<i class="bi bi-file-pdf"></i>`) はすべて不変。

### 変更対象外（不変・現状維持）

| 項目 | 場所 | 理由 |
|---|---|---|
| `downloadReceivingPdf()` JS 本体 | 同 .cshtml `@section Scripts` | 機能不変（Req 2.4） |
| ダウンロードファイル名 `入庫伝票_yyyyMMdd_yyyyMMdd.pdf` | `downloadReceivingPdf()` 内の `fileName` リテラル | 帳票名を維持（Req 2.1） |
| `OnGetExportPdfAsync` | `Index.cshtml.cs` | code-behind 不変（Req 2.3） |
| PDF 内容 | `OrderPdfService` 等 | 出力内容を維持（Req 2.2） |
| 他ボタン・他要素（表示 / 本日納入分 / 入庫 / 更新 / 編集 等） | 同 .cshtml | ラベル変更以外は維持（Req 2.4） |
| clnCoCore（MainWeb / AuthModule / SharedCore 等） | 別ソリューション | 変更禁止（プロジェクトルール） |

## Architecture

本変更はプレゼンテーション層（Razor ビュー）の静的テキストのみに閉じる。処理フロー・依存関係・DI・ルーティングへの影響は無い。

```
ユーザー ──クリック──> [PDF出力ボタン(表示: 印刷)] ──onclick──> downloadReceivingPdf()
                                    │                              │(不変)
                              表示ラベルのみ変更                    ▼
                                                        fetch ExportPdf ハンドラ
                                                                   │(不変)
                                                                   ▼
                                                        OnGetExportPdfAsync → PDF(不変)
                                                        fileName: 入庫伝票_...pdf(不変)
```

ボタンのテキストラベル（利用者向け UI 表記）と、ダウンロードファイル名に含まれる帳票名「入庫伝票」は別概念であり、前者のみを「印刷」に変更する。両者を混同しないことが本設計の要点。

## Components and Interfaces

新規・変更コンポーネントなし。既存の Razor ビューのテキストノード1箇所を編集するのみ。

- フロントエンド: Bootstrap 5 + vanilla JavaScript（既存構成を踏襲）
- 編集手段: `str_replace` によるテキストノードの単一置換（PowerShell による書き込みは禁止）

## Data Models

変更なし。

## Error Handling

変更なし。既存の `downloadReceivingPdf()` 内 `catch` による `alert` 表示、`response.ok` 判定はそのまま維持される。

## Implementation Notes

- 置換は `<i class="bi bi-file-pdf"></i> 入庫伝票` を対象文脈として一意に特定し、`入庫伝票` のみを `印刷` に置き換える。JS 内の `'入庫伝票_...'`（fileName）は対象外とすること（別行・別文脈のため誤置換しない）。
- 変更後は当該ボタン行のインデント・属性順・空白を変更前と一致させる。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

本機能は静的な Razor ビューの表示ラベルを1箇所置換するものであり、入力に応じて挙動が変化する純粋関数的ロジックを含まない。プレワーク分析の結果、全受け入れ基準は EXAMPLE / INTEGRATION / SMOKE に分類され、「For all 入力 X について性質 P(X) が成り立つ」形式の普遍的性質として意味のある定式化はできない。

したがって **プロパティベーステスト対象の項目は無し**。検証は以下の例示的・回帰的確認で担保する（差分レビューおよび画面目視）。

### 検証項目（例示・回帰確認）

- ボタンの表示テキストが「印刷」であること（Req 1.1）
- `onclick="downloadReceivingPdf()"` が維持されていること（Req 1.2）
- class `btn btn-outline-danger btn-sm text-nowrap` が維持されていること（Req 1.3）
- アイコン `<i class="bi bi-file-pdf"></i>` が維持されていること（Req 1.4）
- `TotalCount == 0` で `disabled`、`> 0` で活性となる既存分岐が維持されていること（Req 1.5）
- `downloadReceivingPdf()` 内の `fileName` が `入庫伝票_yyyyMMdd_yyyyMMdd.pdf` のまま維持されていること（Req 2.1）
- code-behind `OnGetExportPdfAsync` および PDF 内容が不変であること（Req 2.2, 2.3、スコープ外・差分無しで担保）
- 差分が当該ボタンのテキスト1点に限定され、他要素が不変であること（Req 2.4）

## Testing Strategy

静的な表示ラベル変更のため、プロパティベーステストは適用しない。検証は以下で行う。

- **差分レビュー**: `str_replace` による変更差分が、当該ボタンのテキスト「入庫伝票」→「印刷」の1点のみであることを確認する。JS 内 `fileName` の `'入庫伝票_'`、`onclick`、`class`、アイコン、`disabled` 制御式、他ボタン・他要素、code-behind に差分が無いことを確認する。
- **画面目視確認**: 入庫管理画面を表示し、PDF 出力ボタンのラベルが「印刷」であること、ボタン押下で従来どおり `入庫伝票_yyyyMMdd_yyyyMMdd.pdf` がダウンロードされ PDF 内容が不変であること、`TotalCount == 0` 時に disabled 表示となることを確認する。
- ビルドはユーザー側で実施する（本プロジェクトルールに従い Kiro からは実行しない）。
