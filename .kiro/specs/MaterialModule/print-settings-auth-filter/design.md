# Design Document

## Overview

PrintSettings 画面（`Areas/Material/Pages/PrintSettings/Index`）の「帳票別 出力プリンタ」について、各帳票（`order_approval`／`dispatch_request`／`receiving`）の設定可否を「その帳票を扱うページ（area=Material）にアクセス可能か」で制御する。

判定方式は clnCoCore の `DbPermissionHandler` と同一（SuperUser 特別扱い＋Claim `max_rank`/`all_section_ids`＋`IContentAuthService.IsAuthorizedForAnySectionAsync`）を踏襲する。UI は案B（行は表示し、Inaccessible は select と「テスト印刷」ボタンを `disabled`）。あわせて `OnPostAsync`・`OnPostTestPrintAsync` にサーバ側防御を追加する。

加えて、同画面の「ページ別 既定設定」カード（発注エントリの出力区分・原材料工場入請求の印刷既定）についても、対応するページへのアクセス権に連動して入力コントロールの有効・無効を切り替え（§8）、保存処理 `OnPostSaveOrderSettingAsync` に項目単位のサーバ側防御（§9）を追加する。判定は帳票別と同じ `BuildReportEditMapAsync`（`report_type → CanEdit`）をそのまま流用し、新規のページ判定ロジックは追加しない（`order_approval`＝`Orders/Create`、`dispatch_request`＝`Dispatches/Index` の可否をカードにも適用）。

変更は `IndexModel`（.cshtml.cs）と `Index.cshtml` の 2 ファイルに閉じる。clnCoCore は読み取り参照のみ・DB スキーマ不変。ページ別既定設定カードは、上記アクセス権連動（無効化・保存時防御）以外の既存挙動（保存値・初期表示ロジック・1 行同時保存）は変更しない。

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

### 8. ページ別既定設定カードの無効化（案B）

「ページ別 既定設定」カード（`Index.cshtml` 内の別 form：`asp-page-handler="SaveOrderSetting"`, `id="pageDefaultForm"`）は次の 2 入力を持つ。

- 発注エントリ（出力区分）: `<select asp-for="DefaultOutputType">`（値 0〜3）→ 対応ページ `Orders/Create`（Report_Type `order_approval` と同判定）。
- 原材料工場入請求（印刷）: `<input asp-for="DispatchPrintDefault" type="checkbox" id="chkDispatchPrintDefault">` → 対応ページ `Dispatches/Index`（Report_Type `dispatch_request` と同判定）。

帳票別で構築済みの `editMap`（`report_type → CanEdit`）には既に `order_approval` と `dispatch_request` の可否が含まれるため、新規のページ判定は追加せずこれを流用する。`IndexModel` に画面表示用の 2 フラグ（画面内 DTO・永続化なし）を追加する。

```csharp
/// <summary>発注エントリ出力区分（Order_Output_Type_Item）の入力を操作可能か。Orders/Create の可否に連動。</summary>
public bool CanEditDefaultOutputType { get; set; }

/// <summary>原材料工場入請求 印刷既定（Dispatch_Print_Item）の入力を操作可能か。Dispatches/Index の可否に連動。</summary>
public bool CanEditDispatchPrintDefault { get; set; }
```

`editMap` を構築する各ハンドラ（`OnGetAsync` / `OnPostAsync` の再表示 / `ReloadAsync`）で、帳票別 `Inputs` を組み立てるのと同じ箇所で 2 フラグを設定する。`report_type` リテラルは既存 `ReportTypes` と同値。

```csharp
CanEditDefaultOutputType   = editMap.TryGetValue("order_approval",   out bool co) && co;
CanEditDispatchPrintDefault = editMap.TryGetValue("dispatch_request", out bool cd) && cd;
```

cshtml は、出力区分 select と印刷チェックボックスに `disabled` を付与する。カード自体・保存ボタン・ラベルは常時表示する（案B・帳票別と同思想）。

```razor
<select asp-for="DefaultOutputType" class="form-select form-select-sm" style="width:auto;"
        disabled="@(!Model.CanEditDefaultOutputType)">
    ...
</select>
```

```razor
<input asp-for="DispatchPrintDefault" class="form-check-input" type="checkbox" id="chkDispatchPrintDefault"
       disabled="@(!Model.CanEditDispatchPrintDefault)" />
```

SuperUser は `editMap` が全帳票 true になるため、両フラグとも true（=操作可能）となり要件 6.5 を満たす。

### 9. OnPostSaveOrderSettingAsync のサーバ側防御（項目単位）

`OnPostSaveOrderSettingAsync` は出力区分と印刷既定を 1 行に同時保存する（`SaveOrderSettingAsync(userCode, outputType, dispatchPrint)`）。案B の無効化を回避した改ざん送信では、`disabled` な select は送信されず `DefaultOutputType` が既定(0) に、`asp-for` の hidden により `DispatchPrintDefault` が false で送信されうるため、送信値をそのまま保存すると担当外項目を上書きしてしまう。よって**項目単位**で防御する。

ハンドラ先頭で `editMap` を 1 回構築し、各項目のアクセス可否を解決する。アクセス可の項目のみ送信値を採用し、不可の項目は保存済みの既存値（`GetDefaultOutputTypeAsync` / `GetDispatchPrintDefaultAsync`）を維持する。

```csharp
public async Task<IActionResult> OnPostSaveOrderSettingAsync()
{
    string userCode = User.Identity?.Name ?? "unknown";

    // 項目単位の防御に用いるアクセス可否マップを1回構築（帳票別と同一：新規ページ判定は追加しない）。
    Dictionary<string, bool> editMap = await BuildReportEditMapAsync();
    bool canOutput   = editMap.TryGetValue("order_approval",   out bool co) && co;
    bool canDispatch = editMap.TryGetValue("dispatch_request", out bool cd) && cd;

    // 出力区分: アクセス可なら送信値を採用し値域検証。不可なら既存値を維持（改ざん送信対策）。
    int outputToSave;
    if (canOutput)
    {
        if (!OutputTypeHelper.IsValid(DefaultOutputType))
        {
            Message = "出力区分の値が不正です。0〜3 のいずれかを選択してください。";
            await ReloadAsync(userCode);
            return Page();
        }
        outputToSave = DefaultOutputType;
    }
    else
    {
        outputToSave = OutputTypeHelper.Normalize(
            await orderSettingService.GetDefaultOutputTypeAsync(userCode));
    }

    // 印刷既定: アクセス可なら送信値、不可なら既存値を維持。
    bool dispatchToSave = canDispatch
        ? DispatchPrintDefault
        : PrintDefaultHelper.Normalize(await orderSettingService.GetDispatchPrintDefaultAsync(userCode));

    try
    {
        await orderSettingService.SaveOrderSettingAsync(userCode, outputToSave, dispatchToSave);
        Message = "既定設定を保存しました。";
    }
    catch (DbUpdateConcurrencyException)
    {
        Message = "他のユーザーが先に更新しました。画面を再読み込みしてください。";
    }

    await ReloadAsync(userCode);
    return Page();
}
```

ポイント:
- 両項目とも不可の場合でも既存値をそのまま再保存するため実質 no-op となり、担当外項目は変更されない。
- 値域検証（`IsValid`）は「出力区分がアクセス可で送信値を採用するとき」にのみ適用する（要件 7.4）。不可時は既存値を `Normalize` するため不正値混入の余地はない。
- 保存ボタンは常時表示（帳票別の保存ボタンと同思想で無効化しない）。
- 競合（`DbUpdateConcurrencyException`）処理・再表示（`ReloadAsync`）は従来どおり。

## Data Models

DB スキーマ変更なし。`MUserPrintSetting` の保存・削除ロジックは既存のまま（Inaccessible をスキップする分岐のみ追加）。ページ別既定設定（出力区分・印刷既定）の保存先・スキーマも既存のまま（`SaveOrderSettingAsync` で 1 行同時保存）で変更しない。

UI 表示用の非永続フィールドを `IndexModel` に追加する（いずれも画面内表示専用・DB へ保存しない）:
- `AssignmentInput.CanEdit`: 帳票別行の編集可否。
- `CanEditDefaultOutputType`: ページ別既定設定カードの出力区分 select の操作可否（`Orders/Create` の可否に連動）。
- `CanEditDispatchPrintDefault`: ページ別既定設定カードの印刷チェックボックスの操作可否（`Dispatches/Index` の可否に連動）。

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

アクセス判定マップ構築・保存/テスト印刷防御は `IContentAuthService`（DB/Claim 依存の IO）・`DbContext`・印刷キューへの副作用に依存し、意味ある普遍的性質を記述できないため代表例・統合テストで検証する。唯一の純粋関数 `ParseSectionIds`（Claim 解析）のみ property-based test 対象とする。

Property test（純粋関数）:
- `ParseSectionIds`: 任意のトークン列に対してカンマ結合→解析で空要素が除去され非空トークンが順序保持されること（Property 1・要件 1.3）。FsCheck.Xunit を使用、最低 100 反復。

Example / Integration test（実施はタスクフェーズで判断）:
- `IContentAuthService` をモックし、可/不可の代表例で `CanEdit`（判定マップ）が正しく解決されること（要件 1.1〜1.2）。
- SuperUser ロール時に全帳票 Accessible となること（要件 1.4）。
- `order_approval` で `Orders/Create/Index` のみ可のモックでも Accessible になること（要件 1.5）。
- `OnPostAsync`: Inaccessible の割当が保存されず、Accessible は保存されること（要件 3.1〜3.3）。
- `OnPostTestPrintAsync`: Inaccessible 時に印刷キュー投入（`EnqueueAsync`）が呼ばれず拒否メッセージが出ること、Accessible 時は従来動作（要件 4.1〜4.3）。
- cshtml: `CanEdit=false` 行で select と「テスト印刷」に `disabled` が付与され、行は表示されること（要件 2.1〜2.4）。

ページ別既定設定カード（§8・§9）も同様に IO/副作用依存（`IContentAuthService`・`IUserOrderSettingService`）のため、property ではなく代表例・統合テストで検証する（実施はタスクフェーズで判断）:
- `CanEditDefaultOutputType` / `CanEditDispatchPrintDefault` が `editMap` の `order_approval` / `dispatch_request` の可否に一致すること（要件 6.1〜6.4）。SuperUser 時は両方 true（要件 6.5）。
- cshtml: フラグ false のとき出力区分 select・印刷チェックボックスに `disabled` が付与され、カード・保存ボタン・ラベルは表示されること（要件 6.2〜6.4）。
- `OnPostSaveOrderSettingAsync`: 出力区分がアクセス不可のとき送信値が採用されず既存値が維持されること、アクセス可のとき送信値が保存され値域検証が適用されること（要件 7.1〜7.4）。印刷既定についても不可時は既存値維持・可時は送信値採用（要件 7.1〜7.3）。両項目不可時は既存値の再保存で実質 no-op となること。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

本機能の大半（アクセス判定マップ構築・保存/テスト印刷防御・ページ別既定設定カードの無効化と保存時防御）は外部認可サービス（`IContentAuthService`）・`IUserOrderSettingService` と DB/印刷キュー/UI への副作用に依存する IO 的処理であり、普遍的性質を意味あるかたちで記述できない（Testing Strategy の代表例・統合テストで検証）。§8・§9 の追加でも新規の純粋関数は増えないため property は追加しない。テスト可能な純粋関数は Claim 解析 `ParseSectionIds` のみで、以下 1 件を property 化する。

### Property 1: 所属ID解析は空要素を除去し非空トークンを保持する

*For any* 非空トークン（カンマを含まない）の列について、それらをカンマで結合した文字列を `ParseSectionIds` で解析すると、結果は元の非空トークン列と順序を含めて一致する。また、空要素（連続カンマ・先頭/末尾カンマ・空文字列）は結果から除去される。

**Validates: Requirements 1.3**
