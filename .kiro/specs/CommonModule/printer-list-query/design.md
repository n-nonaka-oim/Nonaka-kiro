# 設計書

## はじめに

CommonModule に、サーバ登録プリンタ一覧（`m_printer`）を読み取り取得する公開I/F `IPrinterQueryService` を追加する。利用側（MaterialModule）はこれを注入して、ユーザーの PDFエージェント出力プリンタ選択UIの選択元とする。読み取り専用・スキーマ変更なし・既存I/Fへ非影響。

## アーキテクチャ

```
利用側（MaterialModule 等）
    │  IPrinterQueryService（注入）
    ▼
PrinterQueryService（CommonModule・internal）
    │  CommonDbContext.Printers（m_printer, AsNoTracking）
    ▼
IReadOnlyList<PrinterInfo>
```

- 公開は `CommonModule.Services` 名前空間。実装は internal（DemoModule パターン：public interface + internal 実装）。
- DI 登録は `CommonModuleExtensions.AddCommonModule` に追加（Scoped）。
- 利用側は `CommonDbContext` を直接参照せず、インターフェース経由でのみ取得。

## コンポーネント設計

### PrinterInfo（公開 record・DTO）

```csharp
namespace CommonModule.Services;

public sealed record PrinterInfo(
    string MachineName,
    string PrinterName,
    bool IsDefault,
    bool IsActive,
    DateTime? LastSeenAt);
```

### IPrinterQueryService（公開インターフェース）

```csharp
namespace CommonModule.Services;

public interface IPrinterQueryService
{
    /// <summary>有効なサーバ登録プリンタ一覧を取得する（読み取り専用）。</summary>
    /// <param name="machineName">絞り込み対象マシン名。null/空なら全マシン。</param>
    Task<IReadOnlyList<PrinterInfo>> GetAvailablePrintersAsync(
        string? machineName = null, CancellationToken ct = default);
}
```

### PrinterQueryService（internal 実装）

```csharp
internal sealed class PrinterQueryService(CommonDbContext db) : IPrinterQueryService
{
    public async Task<IReadOnlyList<PrinterInfo>> GetAvailablePrintersAsync(
        string? machineName = null, CancellationToken ct = default)
    {
        IQueryable<MPrinter> q = db.Printers.AsNoTracking().Where(p => p.IsActive);

        if (!string.IsNullOrWhiteSpace(machineName))
            q = q.Where(p => p.MachineName == machineName);

        return await q
            .OrderBy(p => p.MachineName).ThenBy(p => p.PrinterName)
            .Select(p => new PrinterInfo(
                p.MachineName, p.PrinterName, p.IsDefault, p.IsActive, p.LastSeenAt))
            .ToListAsync(ct);
    }
}
```

### DI 登録（CommonModuleExtensions）

```csharp
services.AddScoped<IPrinterQueryService, PrinterQueryService>();
```

## エラー処理

- DB 例外は握りつぶさず呼び出し元へ伝播（利用側でハンドリング）。本サービスは副作用なし。
- 該当行なしは空リストを返す（例外にしない）。

## 正しさのプロパティ

- **Property 1（有効フィルタ）**: 返る全要素は `IsActive == true`。
- **Property 2（マシン絞り込み）**: `machineName` 指定時、返る全要素の `MachineName == machineName`。null/空なら絞り込まない。
- **Property 3（並び）**: 結果は (MachineName, PrinterName) の昇順で単調。

## テスト戦略

- `CommonModule.Tests`（既存プロジェクト）に InMemory `CommonDbContext` を用いた単体/プロパティテストを追加（任意）。
  - is_active フィルタ・machine 絞り込み・並び順を検証。
- ビルド・実行はユーザー（project-rules）。
