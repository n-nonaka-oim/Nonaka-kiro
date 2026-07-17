# Design Document

## Overview

PrintSettings 画面（`Areas/Material/Pages/PrintSettings/Index`）の「帳票別 出力プリンタ」について、各帳票（`order_approval`／`dispatch_request`／`receiving`）の設定可否を「その帳票を扱うページ（area=Material）にアクセス可能か」で制御する。

判定方式は clnCoCore の `DbPermissionHandler` と同一（SuperUser 特別扱い＋Claim `max_rank`/`all_section_ids`＋`IContentAuthService.IsAuthorizedForAnySectionAsync`）を踏襲する。UI は案B（行は表示し、Inaccessible は select と「テスト印刷」ボタンを `disabled`）。あわせて `OnPostAsync`・`OnPostTestPrintAsync` にサーバ側防御を追加する。

変更は `IndexModel`（.cshtml.cs）と `Index.cshtml` の 2 ファイルに閉じる。clnCoCore は読み取り参照のみ・DB スキーマ不変・ページ別既定設定カードは不変。

## Architecture

```
Browser (PrintSettings/Index)
        │  GET / POST(save) / POST(TestPrint)
        ▼
IndexModel (MaterialModule)
        │  BuildReportEditMapAsync()  … report_type → CanEdit を1回構築
        │    ├─ User.IsInRole("SuperUser") → 全帳票 true
        │    └─ Claim(max_rank / all_section_ids) を1回解析（ParseSectionIds）
        ▼
IContentAuthService.IsAuthorizedForAnySectionAsync(maxRank, sectionIds, "Material", page)
        │  (SharedCore 経由・DI 済み・clnCoCore 側 / 読み取り参照のみ)
        ▼
        Dictionary<string,bool> → AssignmentInput.CanEdit / サーバ側スキップ・拒否
```

判定マップは各ハンドラ（`OnGetAsync` / `ReloadAsync` / `OnPostAsync` / `OnPostTestPrintAsync`）で 1 回だけ構築し共用する。

依存境界:
- `IndexModel` は SharedCore の `IContentAuthService` をコンストラクタ注入で受け取る（既存 DI 済み）。
- AuthModule への参照は不可（MaterialModule は SharedCore のみ参照）。そのため Claim キーは AuthModule の `ClaimKeys` を参照せず、同値のリテラル `"max_rank"`／`"all_section_ids"` を用い、コメントで `AuthModule.Constants.ClaimKeys` と同値である旨を明記する。

## Components and Interfaces

### 1. IndexModel コンストラクタへの注入追加

既存のコンストラクタ引数末尾に `IContentAuthService contentAuthService` を追加する。

```csharp
public class IndexModel(
    MaterialDbContext context,
    IPrinterQueryService printerQuery,
    IPrintOutputResolver printOutputResolver,
    IPrintQueueService printQueueService,
    ISmtpQueueService smtpQueueService,
    ISendConfigService sendConfigService,
    IPrintOutputPathService printOutputPathService,
    IUserOrderSettingService orderSettingService,
    IContentAuthService contentAuthService) : PageModel
```

using に `SharedCore.Interfaces;` と `System.Security.Claims;` を追加する。

### 2. 帳票→ページ対応（Report_Page_Map）

`ReportTypeDef` に対応ページ `Page` を持たせる（別マップを持たず定義を単一に保つ）。area は全帳票 `"Material"` 固定のため定数で扱う。

```csharp
public record ReportTypeDef(string ReportType, string Label, string Page);

public static readonly IReadOnlyList<ReportTypeDef> ReportTypes = new[]
{
    new ReportTypeDef("order_approval",   "発注書兼納入依頼書", "Orders/Create"),
    new ReportTypeDef("dispatch_request", "原材料工場入請求",   "Dispatches/Index"),
    new ReportTypeDef("receiving",        "入庫伝票",           "Receivings/Index"),
};

private const string AuthArea = "Material";
```

### 3. Claim 解析ヘルパー（純粋関数）と判定マップ構築

Claim `all_section_ids` の分割は副作用のない純粋 static ヘルパ `ParseSectionIds` に切り出し、単体で検証可能にする（カンマ分割＋空要素除去）。判定マップ `BuildReportEditMapAsync` は SuperUser 特別扱いと Claim 解析を 1 回だけ行い、`report_type → CanEdit` の `Dictionary<string,bool>` を構築して各ハンドラで共用する。判定方式は `DbPermissionHandler` に準拠。

```csharp
/// <summary>
/// Claim all_section_ids（カンマ区切り）を所属ID群へ分割する純粋関数。空要素は除去する。
/// </summary>
internal static List<string> ParseSectionIds(string? allSectionIds) =>
    string.IsNullOrEmpty(allSectionIds)
        ? []
        : allSectionIds.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList();

/// <summary>
/// 各帳票種別の対応ページ（area=Material）にアクセス可能かを 1 回だけ判定し、
/// report_type → CanEdit のマップを構築する。判定方式は AuthModule.DbPermissionHandler に準拠
/// （SuperUser 特別扱い＋Claim max_rank/all_section_ids＋IContentAuthService）。
/// </summary>
private async Task<Dictionary<string, bool>> BuildReportEditMapAsync()
{
    // SuperUser は全帳票アクセス可（DbPermissionHandler と同じ扱い）。
    if (User.IsInRole("SuperUser"))
        return ReportTypes.ToDictionary(r => r.ReportType, _ => true);

    // Claim キーは AuthModule.Constants.ClaimKeys.MaxRank / AllSectionIds と同値のリテラル
    // （MaterialModule は AuthModule を参照しないためリテラルで指定）。
    if (!int.TryParse(User.FindFirstValue("max_rank"), out int maxRank))
        maxRank = 0;

    List<string> sectionIds = ParseSectionIds(User.FindFirstValue("all_section_ids"));

    var map = new Dictionary<string, bool>(ReportTypes.Count);
    foreach (ReportTypeDef rt in ReportTypes)
    {
        // 所属未設定は不可扱い（安全側）。
        map[rt.ReportType] = sectionIds.Count != 0
            && await IsPageAuthorizedAsync(maxRank, sectionIds, rt.Page);
    }
    return map;
}

/// <summary>
/// 対応ページ（area=Material）へのアクセス可否。Razor Pages の /Index 省略規約に合わせ、
/// page と page/Index の OR で評価する（DbPermissionHandler と同じ二段チェック）。
/// </summary>
private async Task<bool> IsPageAuthorizedAsync(int maxRank, List<string> sectionIds, string page)
{
    if (await contentAuthService.IsAuthorizedForAnySectionAsync(maxRank, sectionIds, AuthArea, page))
        return true;

    if (!page.EndsWith("/Index", StringComparison.OrdinalIgnoreCase) && page != "Index")
    {
        return await contentAuthService.IsAuthorizedForAnySectionAsync(
            maxRank, sectionIds, AuthArea, $"{page}/Index");
    }
    return false;
}
```

補足: `order_approval` の対応ページは `"Orders/Create"` のため、上記二段チェックにより `Orders/Create` と `Orders/Create/Index` の OR が要件 1.5 のとおり自動的に満たされる（帳票個別の特別分岐は不要）。

### 4. AssignmentInput への CanEdit 追加

```csharp
public class AssignmentInput
{
    public string ReportType { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public string? PrinterName { get; set; }
    /// <summary>当該帳票の対応ページにアクセス可能か（=編集可否／Accessible_Report）。</summary>
    public bool CanEdit { get; set; }
}
```

`OnGetAsync` / `ReloadAsync` の `Inputs` 構築時に、事前に構築した判定マップから各帳票の `CanEdit` を引く。マップ構築（`BuildReportEditMapAsync`）は各ハンドラで 1 回だけ呼ぶ。`OnPostAsync` 内の再表示 `Inputs` 構築も同じマップを使う。

```csharp
Dictionary<string, bool> editMap = await BuildReportEditMapAsync();
Inputs = ReportTypes.Select(rt => new AssignmentInput
{
    ReportType = rt.ReportType,
    Label = rt.Label,
    PrinterName = current.TryGetValue(rt.ReportType, out string? p) ? p : null,
    CanEdit = editMap.TryGetValue(rt.ReportType, out bool can) && can,
}).ToList();
```

### 5. cshtml（案B・行は表示、Inaccessible は無効化）

各行で `Model.Inputs[i].CanEdit` を評価し、`!CanEdit` のとき select と「テスト印刷」ボタンに `disabled` を付与する。行自体は従来どおり表示する。ページ別既定設定カードは変更しない。

```razor
<select asp-for="Inputs[i].PrinterName" class="form-select form-select-sm" style="max-width:420px;"
        disabled="@(!Model.Inputs[i].CanEdit)">
    ...
</select>
```

```razor
<button type="submit" asp-page-handler="TestPrint"
        asp-route-reportType="@Model.Inputs[i].ReportType"
        formnovalidate class="btn btn-outline-secondary btn-sm"
        disabled="@(!Model.Inputs[i].CanEdit)">
    <i class="bi bi-printer"></i> テスト印刷
</button>
```

補足: 任意で Inaccessible 行に「権限なし」等の控えめな表示を添えてよいが、必須ではない（要件は行表示＋無効化のみ）。

### 6. OnPostAsync のサーバ側防御

保存ループの前に判定マップを 1 回構築し、ループ内で対象 `reportType` が Inaccessible なら追加・更新・削除を行わず `continue` する（クライアント無効化を回避した改ざん送信への防御）。構築したマップは保存後の再表示 `Inputs` 構築でも再利用する。

```csharp
Dictionary<string, bool> editMap = await BuildReportEditMapAsync();

foreach (AssignmentInput input in Inputs)
{
    if (!validTypes.Contains(input.ReportType))
        continue;

    // サーバ側防御: 対応ページにアクセス不可な帳票は保存対象から除外（改ざん送信対策）。
    if (!(editMap.TryGetValue(input.ReportType, out bool can) && can))
        continue;

    // （以降、既存の追加/更新/削除ロジックは変更なし）
}
```

### 7. OnPostTestPrintAsync のサーバ側防御

ハンドラ先頭（プリンタ解決・キュー投入の前）で Inaccessible を判定し、拒否メッセージを設定して `ReloadAsync` 後に `return Page()`。既存のプリンタ未設定チェック等はその後に続ける。

```csharp
public async Task<IActionResult> OnPostTestPrintAsync(string reportType, CancellationToken ct)
{
    string userCode = User.Identity?.Name ?? "unknown";

    // サーバ側防御: アクセス不可帳票はキュー投入前に拒否。
    Dictionary<string, bool> editMap = await BuildReportEditMapAsync();
    if (!(editMap.TryGetValue(reportType, out bool can) && can))
    {
        Message = "この帳票のテスト印刷を実行する権限がありません。";
        await ReloadAsync(userCode);
        return Page();
    }

    // （以降、既存のプリンタ解決〜キュー投入は変更なし）
}
```

## Data Models

DB スキーマ変更なし。`MUserPrintSetting` の保存・削除ロジックは既存のまま（Inaccessible をスキップする分岐のみ追加）。UI 表示用に `AssignmentInput.CanEdit`（画面内 DTO・永続化なし）を追加する。

Report_Page_Map（area 固定 = `Material`）:

| Report_Type | 対応ページ | OR 追加チェック |
|---|---|---|
| order_approval | Orders/Create | Orders/Create/Index |
| dispatch_request | Dispatches/Index | （末尾 /Index のため追加なし） |
| receiving | Receivings/Index | （末尾 /Index のため追加なし） |

## Error Handling

- Claim `max_rank` が欠落／不正: `maxRank = 0`（DbPermissionHandler と同じフォールバック）。
- Claim `all_section_ids` が空: `sectionIds` 空 → 非 SuperUser は Inaccessible として扱う（安全側）。
- `IsAuthorizedForAnySectionAsync` の例外は握りつぶさず既存のページ例外処理に委ねる（新たな try/catch は追加しない）。保存時の `DbUpdateConcurrencyException` は既存どおり競合メッセージで処理。
- テスト印刷拒否時はキュー投入を行わず、拒否メッセージ表示＋`ReloadAsync` で現在状態を再表示する。

## Testing Strategy

アクセス判定は `IContentAuthService`（DB/Claim 依存の IO）への薄い委譲、保存・テスト印刷防御は `DbContext`・印刷キューへの副作用検証であり、いずれも「for all inputs で成り立つ純粋な性質」を意味あるかたちで記述できない。したがって本機能に property-based test 対象は無し（設計判断）。検証は以下の代表例・統合テストで行う（実施はタスクフェーズで判断）。

- `IContentAuthService` をモックし、可/不可の代表例で `CanEdit` が正しく解決されること（要件 1.1〜1.5）。
- SuperUser ロール時に全帳票 Accessible となること（要件 1.4）。
- `order_approval` で `Orders/Create/Index` のみ可のモックでも Accessible になること（要件 1.5）。
- `OnPostAsync`: Inaccessible の割当が保存されず、Accessible は保存されること（要件 3.1〜3.3）。
- `OnPostTestPrintAsync`: Inaccessible 時に印刷キュー投入（`EnqueueAsync`）が呼ばれず拒否メッセージが出ること、Accessible 時は従来動作（要件 4.1〜4.3）。
- cshtml: `CanEdit=false` 行で select と「テスト印刷」に `disabled` が付与され、行は表示されること（要件 2.1〜2.4）。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

本機能の全アクセス判定・防御ロジックは外部認可サービス（`IContentAuthService`）と DB/印刷キューへの副作用に依存する IO 的処理であり、純粋関数として普遍的性質（For all …）を意味あるかたちで記述できるものが無い。したがって property-based test 対象のプロパティは定義しない（設計判断）。上記 Testing Strategy の代表例・統合テストで要件を検証する。
