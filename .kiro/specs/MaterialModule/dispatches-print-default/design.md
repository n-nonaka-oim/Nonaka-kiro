# Design Document

## Overview

原材料工場入請求画面（`Areas/Material/Pages/Dispatches/Index`）未登録ビューの印刷チェックボックス（`id="chkPdfOutput"`）の**初期チェック状態のみ**を、ユーザーごとの「印刷既定（ON/OFF）」に従わせる。設定値は既存の per-user 設定マスタ `m_user_order_setting`（1ユーザー1行）に列 `dispatch_print_default`（bit・既定1=ON）を追加して保持し、既存列 `default_output_type` は一切変更しない。設定 UI は既存の自己サービス画面 `PrintSettings/Index` の「発注エントリ 既定出力区分」フォームに相乗りさせる。

本機能は MaterialModule 内で完結する。clnCoCore（MainWeb / AuthModule / SharedCore）は変更しない。実装は `str_replace` / `fs_write` のみで行い、ビルド・SQL 実行は行わない。

### 設計判断（確定事項）

- **保存の統合**: PrintSettings の既定出力区分フォーム（`asp-page-handler="SaveOrderSetting"`）へチェックボックスを相乗りさせ、既定出力区分と印刷既定を**同一 POST・同一 SaveChangesAsync（1トランザクション）**でアップサートする。専用ハンドラは新設しない。
- **サービス**: 既存 `IUserOrderSettingService` に取得 `GetDispatchPrintDefaultAsync` を追加し、保存は「1行に両列をアップサートする」統合メソッド `SaveOrderSettingAsync(userCode, outputType, dispatchPrintDefault)` を追加する。既存 `GetDefaultOutputTypeAsync` / `SaveDefaultOutputTypeAsync`（Orders/Create モーダル用）は**シグネチャ・挙動とも不変**で残す。
- **フォールバック**: 未設定（行なし / null）は ON。`OutputTypeHelper` と同型の純粋ヘルパ `PrintDefaultHelper.Normalize(bool?) => value ?? true` で解決し、`Dispatches/Index` と `PrintSettings/Index` の両方から共有する。
- **Dispatches 側の適用範囲**: `chkPdfOutput` の初期 `checked` 属性のみを条件化する。要素 id・送信プロパティ名 `PdfOutput`・JS の読み取り/分岐・`OnPostSubmit` の PDF 分岐・外部出力（PDFエージェント）は不変。

## Architecture

```
PrintSettings/Index (自己サービス設定)
  ├─ [BindProperty] int  DefaultOutputType      （既存）
  └─ [BindProperty] bool DispatchPrintDefault   （新規）
        │  OnPostSaveOrderSettingAsync（既存ハンドラを拡張：両値を1回で保存）
        ▼
IUserOrderSettingService
  ├─ GetDefaultOutputTypeAsync(userCode)                    （既存・不変）
  ├─ SaveDefaultOutputTypeAsync(userCode, outputType)       （既存・不変：Orders/Create 用）
  ├─ GetDispatchPrintDefaultAsync(userCode)                 （新規：bool? 生値）
  └─ SaveOrderSettingAsync(userCode, outputType, dispPrint) （新規：1行へ両列アップサート）
        │
        ▼
MaterialDbContext.UserOrderSettings  →  m_user_order_setting（1ユーザー1行）
        既存: default_output_type / row_version
        新規: dispatch_print_default（bit, 既定1）

Dispatches/Index (原材料工場入請求)
  OnGetAsync: DispatchPrintDefault = PrintDefaultHelper.Normalize(
                  await GetDispatchPrintDefaultAsync(userCode))
  cshtml:    <input id="chkPdfOutput" ... @(Model.DispatchPrintDefault ? "checked" : null) />
  JS:        既存の PdfOutput 読み取り・送信・分岐は不変

PrintDefaultHelper.Normalize(bool?)  … 純粋関数（フォールバック ON）
```

依存方向は既存どおり。`Dispatches/Index` は表示解決のため `IUserOrderSettingService` を新たに注入する（読み取りのみ）。

## Components and Interfaces

### 1. エンティティ `MUserOrderSetting`（列追加）

`Data/Entities/MUserOrderSetting.cs` に列を1つ追加する。既存列・属性は不変。

```csharp
/// <summary>
/// 原材料工場入請求の印刷既定（true=印刷ON/false=OFF）。未設定行の既定は DB 側 1(ON)。
/// Dispatches 未登録ビューの印刷チェックボックス初期状態にのみ使用する。
/// </summary>
[Required]
[Column("dispatch_print_default")]
public bool DispatchPrintDefault { get; set; } = true;
```

### 2. 純粋ヘルパ `PrintDefaultHelper`（新規）

`Services/PrintDefaultHelper.cs`。`OutputTypeHelper` と同型で、DB/HTTP 非依存のためプロパティテスト対象とする。

```csharp
namespace MaterialModule.Services;

/// <summary>
/// 印刷既定（ON/OFF）のフォールバック解決を担う純粋ヘルパ。
/// 保存値が存在すればその値、未設定(null)なら ON(true) を返す。
/// </summary>
public static class PrintDefaultHelper
{
    /// <summary>フォールバック既定値（ON）。</summary>
    public const bool Fallback = true;

    /// <summary>表示用の印刷既定を解決する。null は <see cref="Fallback"/>（true）。</summary>
    public static bool Normalize(bool? value) => value ?? Fallback;
}
```

### 3. サービス `IUserOrderSettingService` / `UserOrderSettingService`

インターフェースに取得・統合保存を追加。既存メソッドは不変。

```csharp
/// <summary>本人の印刷既定の「生値」を返す（未設定・行なしは null）。</summary>
Task<bool?> GetDispatchPrintDefaultAsync(string userCode);

/// <summary>
/// 本人の m_user_order_setting 1 行へ、既定出力区分と印刷既定を一括アップサートする
/// （未存在は作成、存在は更新）。両列を同一 SaveChangesAsync で保存する。
/// 出力区分は OutputTypeHelper.IsValid を満たさない値で ArgumentOutOfRangeException。
/// 競合は DbUpdateConcurrencyException として呼び出し側へ伝播する。
/// </summary>
Task SaveOrderSettingAsync(string userCode, int outputType, bool dispatchPrintDefault);
```

実装（既存 `SaveDefaultOutputTypeAsync` のアップサート作法を踏襲）:

```csharp
public async Task<bool?> GetDispatchPrintDefaultAsync(string userCode)
{
    MUserOrderSetting? row = await context.UserOrderSettings
        .AsNoTracking()
        .FirstOrDefaultAsync(s => s.UserCode == userCode);
    return row?.DispatchPrintDefault;
}

public async Task SaveOrderSettingAsync(string userCode, int outputType, bool dispatchPrintDefault)
{
    if (!OutputTypeHelper.IsValid(outputType))
        throw new ArgumentOutOfRangeException(nameof(outputType));

    DateTime now = DateTime.UtcNow;
    MUserOrderSetting? row = await context.UserOrderSettings
        .FirstOrDefaultAsync(s => s.UserCode == userCode);

    if (row == null)
    {
        context.UserOrderSettings.Add(new MUserOrderSetting
        {
            UserCode = userCode,
            DefaultOutputType = outputType,
            DispatchPrintDefault = dispatchPrintDefault,
            CreatedAt = now,
            UpdatedAt = now,
        });
    }
    else if (row.DefaultOutputType != outputType || row.DispatchPrintDefault != dispatchPrintDefault)
    {
        row.DefaultOutputType = outputType;
        row.DispatchPrintDefault = dispatchPrintDefault;
        row.UpdatedAt = now;
    }

    await context.SaveChangesAsync(); // DbUpdateConcurrencyException は呼び出し側で捕捉
}
```

### 4. `PrintSettings/Index`（設定 UI・保存の統合）

- code-behind: `[BindProperty] public bool DispatchPrintDefault { get; set; }` を追加。
- `OnGetAsync` / `ReloadAsync` / `OnPostAsync` の末尾で、既定出力区分の再解決と並べて
  `DispatchPrintDefault = PrintDefaultHelper.Normalize(await orderSettingService.GetDispatchPrintDefaultAsync(userCode));` を実行。
- `OnPostSaveOrderSettingAsync`: 既存の出力区分値域検証を維持したうえで、保存呼び出しを統合メソッドへ差し替える:
  `await orderSettingService.SaveOrderSettingAsync(userCode, DefaultOutputType, DispatchPrintDefault);`
  競合メッセージ・値域不正メッセージは既存のまま流用（新規追加なし）。
- cshtml: 「発注エントリ 既定出力区分」フォーム（`asp-page-handler="SaveOrderSetting"`）内に、既定出力区分 select の近くへチェックボックスを1つ追加する。

```html
<div class="form-check">
    <input asp-for="DispatchPrintDefault" class="form-check-input" type="checkbox" id="chkDispatchPrintDefault" />
    <label asp-for="DispatchPrintDefault" class="form-check-label" style="font-size: 0.75rem;">
        原材料工場入請求 印刷 既定（ON/OFF）
    </label>
</div>
```

`asp-for="DispatchPrintDefault"` を用いるため checkbox の隠しフィールドも自動生成され、既存の同一フォーム内 `SaveOrderSetting` 送信で bool として確実にバインドされる。

### 5. `Dispatches/Index`（初期チェック状態の反映）

- code-behind: コンストラクタに `IUserOrderSettingService orderSettingService` を追加注入。公開プロパティ
  `public bool DispatchPrintDefault { get; set; } = true;` を追加。
- `OnGetAsync` 内で解決:
  `string userCode = User.Identity?.Name ?? "unknown";`
  `DispatchPrintDefault = PrintDefaultHelper.Normalize(await orderSettingService.GetDispatchPrintDefaultAsync(userCode));`
  （登録・削除・請求などの POST 経路は不変。初期表示 GET のみ。）
- cshtml: 既存のハードコード `checked` を条件化する（**この一箇所のみ変更**）:

```html
<input type="checkbox" id="chkPdfOutput" class="form-check-input" @(Model.DispatchPrintDefault ? "checked" : null) />
```

`@(... ? "checked" : null)` は false 時に属性自体を出力しない（Razor の属性 null 省略）。要素 id・`PdfOutput` の送信名・`submitEntries()` の `chkPdfOutput.checked` 読み取り・PDF 分岐は不変。

### 6. スキーマ変更 SQL（新規・冪等）

`MaterialModule/docs/sql/material/alter_m_user_order_setting_add_dispatch_print_default.sql`。既存 `create_m_user_order_setting.sql` のヘッダ規約（USE なし・対象論理ロール material・冪等）に準拠。

```sql
-- =============================================================
-- 対象論理ロール: material
-- 物理DB名: dev=db_material_dev / staging=db_material_staging / prod=db_material_prod
-- ※ 実行時は対象DBを選択して適用すること（USE句は環境非依存化のため削除済み）
-- =============================================================

/* =========================================================================
 * m_user_order_setting に dispatch_print_default 列を追加（dispatches-print-default）
 *   用途: 原材料工場入請求（Dispatches/Index 未登録ビュー）の印刷チェックボックス
 *         初期状態をユーザーごとに保持する。bit・既定 1(ON)。未設定時は ON フォールバック。
 *   注意: 冪等（列存在チェック付き）。既存 default_output_type は変更しない。
 * ========================================================================= */

IF COL_LENGTH('dbo.m_user_order_setting', 'dispatch_print_default') IS NULL
BEGIN
    ALTER TABLE dbo.m_user_order_setting
        ADD dispatch_print_default BIT NOT NULL
            CONSTRAINT DF_m_user_order_setting_dispatch_print_default DEFAULT (1);
    PRINT 'Added column dispatch_print_default to m_user_order_setting';
END
ELSE
    PRINT 'Skip add (dispatch_print_default already exists).';
GO
```

NOT NULL + DEFAULT(1) のため既存行は 1(ON) で backfill される（要件 2.1 の既定 ON と整合）。

### 7. DB 文書更新

- `.kiro/docs/db/テーブル定義書.md`: `m_user_order_setting` に行を追加（列名 `dispatch_print_default` / 日本語名「原材料工場入請求 印刷既定」/ 型 bit / 備考「既定1=ON、未設定時 ON フォールバック」）。
- `.kiro/docs/db/ER図.md`（存在すれば `ER図.mmd` も）: `m_user_order_setting` エンティティへ当該列を追記。

## Data Models

`m_user_order_setting`（1ユーザー1行、`user_code` 一意）:

| 列 | 型 | 変更 | 備考 |
|---|---|---|---|
| id | int identity | 既存 | PK |
| user_code | nvarchar(40) | 既存 | 一意 |
| default_output_type | int | 不変 | 0/1/2/3 |
| **dispatch_print_default** | **bit** | **新規** | **既定1=ON。未設定時 ON フォールバック** |
| created_at / updated_at | datetime | 既存 | 監査 |
| row_version | rowversion | 既存 | 楽観的ロック（流用） |

## Error Handling

- **楽観的ロック競合**: `SaveOrderSettingAsync` 内の `SaveChangesAsync` が投げる `DbUpdateConcurrencyException` を `OnPostSaveOrderSettingAsync` が既存どおり捕捉し、既存メッセージ「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示（新規メッセージなし）。既存 `row_version` を流用。
- **出力区分の値域不正**: 既存 `OutputTypeHelper.IsValid` 検証を維持。不正時は保存せず既存メッセージ。印刷既定は bool のため値域検証不要。
- **未設定/行なし**: `GetDispatchPrintDefaultAsync` は null を返し、`PrintDefaultHelper.Normalize` が ON(true) へフォールバック。
- **Dispatches 初期表示の取得失敗**: 読み取りは GET のみで副作用なし。既定プロパティ初期値 true によりフェイルセーフ（ON 表示）。

## Testing Strategy

- **Property tests**（FsCheck.Xunit・最低100反復）: `PrintDefaultHelper.Normalize` の普遍則（Property 1）。純粋・低コストのため採用。
- **Unit tests（EXAMPLE/EDGE_CASE）**:
  - `SaveOrderSettingAsync`: 未存在→作成（両列）、存在→更新、既定出力区分の非改変（true/false・0/1/2/3）を InMemoryDB で検証。
  - `GetDispatchPrintDefaultAsync`: 行あり（true/false）→生値、行なし→null。
  - 競合: `DbUpdateConcurrencyException` 捕捉→既存メッセージ。
  - 既存 `SaveDefaultOutputTypeAsync` / `GetDefaultOutputTypeAsync` の回帰（挙動不変）。
- **SMOKE/レビュー**: ALTER SQL の冪等性（COL_LENGTH）、`chkPdfOutput` の変更が初期 `checked` 属性のみであること、clnCoCore 無変更、文書更新。
- テストタグ形式: **Feature: dispatches-print-default, Property {number}: {property_text}**。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 印刷既定のフォールバック解決

*For any* `bool?` 入力値について、`PrintDefaultHelper.Normalize` は、値が非 null（true/false）ならその値をそのまま返し、null なら常に ON(true) を返す。

**Validates: Requirements 1.4, 3.3**
