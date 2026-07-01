---
inclusion: fileMatch
fileMatchPattern: "**/clnCoCore/**"
---

> スコープ: 本書は CoCore（Auth）ソリューション（`clnCoCore`）の外部モジュール開発ガイド。MaterialModule 等の作業には適用されない。

# CoCore 外部モジュール開発ガイド

本ドキュメントは、CoCoreソリューション（slnCoCore）の外部に独立したRazorクラスライブラリとして新規モジュールを開発する際のリファレンスです。

## 前提

- 新規モジュールはslnCoCoreソリューションの外部で単独のプロジェクト/ソリューションとして作成される
- CoCoreのソースコードを直接参照することはできない
- SharedCore等の利用はアセンブリ参照（DLL）またはプロジェクト参照で行う
- レイアウト、CSS、JavaScript、静的ファイルはすべてMainWeb側が提供するため、モジュール側からは直接見えない
- ランタイムでMainWebにホストされることで、レイアウトやDIコンテナの恩恵を受ける

---

## 1. CoCoreソリューションの概要

```
slnCoCore.sln
├── MainWeb/              # Composition Root (Microsoft.NET.Sdk.Web) — ホストアプリケーション
├── AuthModule/           # 認証・認可モジュール (Microsoft.NET.Sdk.Razor)
├── SharedCore/           # ドメイン層: モデル、インターフェース、DTO (Microsoft.NET.Sdk)
├── SharedInfrastructure/ # インフラ層: DbContext、リポジトリ、マイグレーション (Microsoft.NET.Sdk)
└── AuthModule.Tests/     # テスト (Microsoft.NET.Sdk)
```

新規モジュールが参照できるのはSharedCoreのみ。SharedInfrastructure、AuthModule、MainWebは参照禁止。

---

## 2. プロジェクトの作成

### 2.1 csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Razor">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AddRazorSupportForMvc>true</AddRazorSupportForMvc>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>

  <!-- SharedCoreへの参照（いずれかの方法を選択） -->

  <!-- 方法A: プロジェクト参照（ソースにアクセスできる場合） -->
  <ItemGroup>
    <ProjectReference Include="..\..\slnCoCore\SharedCore\SharedCore.csproj" />
  </ItemGroup>

  <!-- 方法B: アセンブリ参照（DLLのみ提供される場合） -->
  <!--
  <ItemGroup>
    <Reference Include="SharedCore">
      <HintPath>path\to\SharedCore.dll</HintPath>
    </Reference>
  </ItemGroup>
  -->
</Project>
```

### 2.2 DI登録

モジュールルートに `Setup/DependencyInjection.cs` を作成する。

```csharp
using Microsoft.Extensions.DependencyInjection;

namespace YourModule;

public static class DependencyInjection
{
    public static IServiceCollection AddYourModule(this IServiceCollection services)
    {
        // モジュール内のサービスを登録
        // services.AddScoped<IYourService, YourService>();

        return services;
    }
}
```

MainWeb側の `Program.cs` にて登録される（MainWeb側の作業）:

```csharp
builder.Services.AddYourModule();
```

### 2.3 MainWebへの組み込み（MainWeb側の作業）

MainWeb.csproj にモジュールへの参照を追加:

```xml
<!-- プロジェクト参照の場合 -->
<ProjectReference Include="path\to\YourModule.csproj" />

<!-- アセンブリ参照の場合 -->
<Reference Include="YourModule">
  <HintPath>path\to\YourModule.dll</HintPath>
</Reference>
```

---

## 3. ページ構造（Area / Page）

### 3.1 ディレクトリ構成

```
YourModule/
├── Areas/
│   └── YourArea/
│       └── Pages/
│           ├── _ViewImports.cshtml
│           ├── _ViewStart.cshtml
│           ├── Index.cshtml
│           ├── Index.cshtml.cs
│           └── SubPages/
│               ├── Detail.cshtml
│               └── Detail.cshtml.cs
├── Services/
├── DependencyInjection.cs
└── YourModule.csproj
```

### 3.2 _ViewImports.cshtml

各Areaの `Pages/` 直下に必ず配置する。モジュール単独ではMainWebの_ViewImportsが見えないため、必要なusingとTagHelperをすべて自前で宣言する。

```razor
@using Microsoft.AspNetCore.Identity
@using YourModule.Areas.YourArea
@using YourModule.Areas.YourArea.Pages
@using SharedCore.Models
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

### 3.3 _ViewStart.cshtml

MainWebが提供する共有レイアウトを参照する。ランタイムでMainWebにホストされるため、このパスで解決される。

```razor
@{
    Layout = "_Layout.cshtml";
}
```

---

## 4. Razor Pageの書き方

### 4.1 レイアウトが提供するもの（モジュール側では記述不要）

MainWebの `_Layout.cshtml` が以下をすべて提供する。モジュールのページでは `<html>`, `<head>`, `<body>` タグは不要。

```
┌─────────────────────────────────────────┐
│ navbar (固定ヘッダー, 56px)              │
│  [☰] CoCore              [ユーザーメニュー] │
├──────────┬──────────────────────────────┤
│ sidebar  │ main-content                 │
│ (認証時) │  ├ パスワード期限警告          │
│          │  ├ <main class="container-   │
│          │  │  fluid">                   │
│          │  │   @RenderBody() ← ここ     │
│          │  │ </main>                    │
│          │  └ (footer)                   │
└──────────┴──────────────────────────────┘
```

レイアウトが読み込み済みのリソース:

| リソース | 備考 |
|---|---|
| Bootstrap 5.3 CSS | `~/lib/bootstrap/css/bootstrap.min.css` |
| Bootstrap Icons | `~/lib/bootstrap-icons/font/bootstrap-icons.css` |
| カスタムCSS変数 | `~/css/variables.css`（後述） |
| サイトCSS | `~/css/site.css` |
| jQuery | `~/lib/jquery/dist/jquery.min.js` |
| Bootstrap 5.3 JS | `~/lib/bootstrap/js/bootstrap.bundle.min.js` |
| Blazor Server JS | `~/_framework/blazor.server.js` |

これらはページ側で個別に読み込む必要はない。

### 4.2 PageModel（.cshtml.cs）

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace YourModule.Areas.YourArea.Pages;

[Authorize(Policy = "DbPermissionCheck")]
public class IndexModel : PageModel
{
    public void OnGet()
    {
    }
}
```

### 4.3 ビュー（.cshtml）

ページコンテンツのみ記述する。`@RenderBody()` の出力先は `<main class="container-fluid">` 内。

```razor
@page
@model YourModule.Areas.YourArea.Pages.IndexModel
@{
    ViewData["Title"] = "ページタイトル";
}

<h1>ページタイトル</h1>
<p>コンテンツ</p>

@section Scripts {
    @* ページ固有のスクリプト *@
}
```

### 4.4 バリデーションスクリプト

フォームバリデーションが必要なページでは、Scriptsセクションで以下を記述する。jQuery ValidationとjQuery Validation Unobtrusiveはレイアウトでは読み込まれないため、必要なページで明示的に読み込む。

```razor
@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

モジュール内に `_ValidationScriptsPartial.cshtml` が存在しない場合、MainWeb側のものが使用される。独自に定義する場合:

```razor
<script src="~/lib/jquery-validation/dist/jquery.validate.min.js"></script>
<script src="~/lib/jquery-validation-unobtrusive/jquery.validate.unobtrusive.min.js"></script>
```

---

## 5. URLと認可の対応

### 5.1 URL解決ルール

認可システムはURLパスからArea/Pageを自動解決する。PathBase (`/AuthTest`) は自動除去される。

| URL パス | Area | Page |
|---|---|---|
| `/YourArea/Index` | `YourArea` | `Index` |
| `/YourArea/SubPages/Detail` | `YourArea` | `SubPages/Detail` |

### 5.2 認可の使い方

PageModelクラスに `[Authorize(Policy = "DbPermissionCheck")]` 属性を付与するだけでコンテンツベース認可が有効になる。

```csharp
using Microsoft.AspNetCore.Authorization;

[Authorize(Policy = "DbPermissionCheck")]
public class YourPageModel : PageModel { }
```

`Microsoft.AspNetCore.Authorization` は `FrameworkReference Include="Microsoft.AspNetCore.App"` により使用可能。ポリシー名 `"DbPermissionCheck"` はAuthModuleの `ContentAuthorizationPolicyProvider` が動的に解決する。

### 5.3 認可の仕組み（モジュール開発者が意識すべき点）

1. `[Authorize(Policy = "DbPermissionCheck")]` を付与するだけで、URLからArea/Pageが自動解決される
2. DBの `m_content` テーブルにArea/Pageが登録されている必要がある
3. DBの `r_content_auth` テーブルにSectionId + ContentId + RoleIdの組み合わせが登録されている必要がある
4. 複数所属のいずれかで認可されていれば許可（OR論理）
5. `SuperUser` ロールは全コンテンツへのアクセスを許可

### 5.4 DBへのコンテンツ登録

新規ページを認可対象にするには、以下のテーブルにデータ登録が必要（DB管理者またはマイグレーションで対応）:

`m_content` テーブル:

| カラム | 説明 |
|---|---|
| id | コンテンツID（一意） |
| area | Area名（例: `"YourArea"`） |
| page | Page名（例: `"Index"`, `"SubPages/Detail"`） |
| label | サイドバーメニューの表示名 |
| group | メニューグループ名（同グループは折りたたみ表示） |
| sort_order | メニュー表示順 |
| is_visible | メニューに表示するか |

`r_content_auth` テーブル:

| カラム | 説明 |
|---|---|
| id | ID（一意） |
| role_id | ロールID（`m_role.Id`） |
| section_id | 組織ID（`m_section.id`） |
| content_id | コンテンツID（`m_content.id`） |


---

## 6. ユーザー情報の取得

モジュールからはSharedCoreのインターフェース経由でユーザー情報にアクセスする。実装はSharedInfrastructureにあり、DIコンテナで自動解決される。

### 6.1 UserManager（ASP.NET Core Identity標準）

`FrameworkReference Include="Microsoft.AspNetCore.App"` により使用可能。

```csharp
using Microsoft.AspNetCore.Identity;
using SharedCore.Models;

public class YourPageModel(UserManager<ApplicationUser> userManager) : PageModel
{
    public async Task OnGetAsync()
    {
        ApplicationUser? user = await userManager.GetUserAsync(User);
        // user.FullName — 「姓 ミドルネーム 名」
        // user.FullNameKana — 「セイ ミドルネーム メイ」
        // user.LastName, user.FirstName, user.Email 等
    }
}
```

### 6.2 IUserRepository

ユーザーデータへの読み取り専用アクセス。SharedCoreで定義済み。

```csharp
public interface IUserRepository
{
    Task<List<ApplicationUser>> GetAllUsersAsync();
    Task<ApplicationUser?> GetUserByIdAsync(string userId);
    Task<List<string>> GetUserSectionIdsAsync(string userId);
    Task<UserSection?> GetMainUserSectionAsync(string userId);
    Task<List<UserSection>> GetConcurrentUserSectionsAsync(string userId);
}
```

使用例:

```csharp
using System.Security.Claims;
using SharedCore.Interfaces;
using SharedCore.Models;

public class YourPageModel(IUserRepository userRepository) : PageModel
{
    public UserSection? MainSection { get; private set; }

    public async Task OnGetAsync()
    {
        string userId = User.FindFirstValue(ClaimTypes.NameIdentifier)!;
        MainSection = await userRepository.GetMainUserSectionAsync(userId);
        // MainSection?.Section?.DisplayName — 最下位階層の組織名
        // MainSection?.Section?.FullName — 全階層結合の組織名
        // MainSection?.Position?.Title — 役職名
    }
}
```

### 6.3 IRoleManagementService

```csharp
public interface IRoleManagementService
{
    Task<IdentityResult> AssignRoleAsync(ApplicationUser user, string roleName);
    Task<string?> GetUserRoleAsync(ApplicationUser user);
    Task<IdentityResult> RemoveUserRoleAsync(ApplicationUser user);
}
```

### 6.4 IContentAuthService

認可済みメニュー取得等。通常のモジュール開発では使用頻度は低い。

```csharp
public interface IContentAuthService
{
    Task<bool> IsAuthorizedAsync(int maxRank, string sectionId, string area, string page);
    Task<List<MenuItemDto>> GetAuthorizedMenuAsync(int maxRank, string sectionId);
    Task<List<MenuItemDto>> GetAuthorizedMenuForMultipleSectionsAsync(int maxRank, List<string> sectionIds);
    Task<List<MenuItemDto>> GetAllMenuAsync();
}
```

### 6.5 IUserPreferenceService

ユーザーのUI設定（テーマ、サイドバーサイズ）。

```csharp
public interface IUserPreferenceService
{
    Task<string> GetThemeAsync(string userId);          // デフォルト: "light"
    Task UpdateThemeAsync(string userId, string themeMode);
    bool IsValidTheme(string themeMode);
    Task<string> GetSidebarSizeAsync(string userId);    // デフォルト: "medium"
    Task UpdateSidebarSizeAsync(string userId, string sidebarSize);
    bool IsValidSidebarSize(string sidebarSize);
}
```

---

## 7. データモデル

全モデルの名前空間は `SharedCore.Models` に統一されている。SharedCoreを参照することで使用可能。

### 7.1 ApplicationUser（IdentityUser拡張）

| プロパティ | 型 | 説明 |
|---|---|---|
| LastName / FirstName / MiddleName | string? | 氏名 |
| LastNameKana / FirstNameKana / MiddleNameKana | string? | 氏名カナ |
| LoginAt | DateTime? | 最終ログイン日時 |
| IsActive | bool | 有効フラグ |
| IsPasswordResetRequired | bool | パスワードリセット要求 |
| PasswordUpdatedAt | DateTime? | パスワード更新日時 |
| FullName | string (NotMapped) | 「姓 ミドルネーム 名」 |
| FullNameKana | string (NotMapped) | 「セイ ミドルネーム メイ」 |

### 7.2 ApplicationRole（IdentityRole拡張）

| プロパティ | 型 | 説明 |
|---|---|---|
| Rank | int | ロールのランク値（認可判定に使用。値が小さいほど高権限） |

### 7.3 Section（組織）

| プロパティ | 型 | 説明 |
|---|---|---|
| Id | string (PK) | 組織ID |
| Company / Office / Department | string? | 組織階層（上位） |
| Unit1 〜 Unit5 | string? | 組織階層（下位） |
| SortOrder | int | 表示順 |
| FullName | string (NotMapped) | 全階層結合（例: "会社 事業所 部 課 係"） |
| ShortName | string (NotMapped) | Company以外の結合 |
| DisplayName | string (NotMapped) | 最下位階層名のみ |
| HierarchyLevel | int (NotMapped) | 階層の深さ |
| Breadcrumbs | IEnumerable\<string\> (NotMapped) | 階層配列 |

### 7.4 Position（役職）

| プロパティ | 型 | 説明 |
|---|---|---|
| Id | string (PK) | 役職ID |
| Title | string? | 役職名 |
| Rank | int | ランク値 |

### 7.5 UserSection（ユーザー所属 / 中間テーブル）

| プロパティ | 型 | 説明 |
|---|---|---|
| UserId | string (複合PK/FK) | ユーザーID |
| SectionId | string (複合PK/FK) | 組織ID |
| IsMain | bool | 主所属フラグ（ユーザーにつき最大1つ） |
| PositionId | string? (FK) | 役職ID |

ナビゲーション: `ApplicationUser?`, `Section?`, `Position?`

### 7.6 Content（コンテンツ定義）

| プロパティ | 型 | 説明 |
|---|---|---|
| Id | string (PK) | コンテンツID |
| Area | string? | Area名 |
| Page | string? | Page名 |
| Label | string? | メニュー表示名 |
| Group | string? | メニューグループ名 |
| SortOrder | int | 表示順 |
| IsVisible | bool | メニュー表示フラグ |

### 7.7 ContentAuth（コンテンツ認可 / 中間テーブル）

| プロパティ | 型 | 説明 |
|---|---|---|
| Id | string (PK) | ID |
| RoleId | string (FK) | ロールID |
| SectionId | string (FK) | 組織ID |
| ContentId | string (FK) | コンテンツID |

ユニーク制約: `SectionId + ContentId`

### 7.8 UserSetting

| プロパティ | 型 | 説明 |
|---|---|---|
| UserId | string (PK/FK) | ユーザーID |
| ThemeMode | string? | テーマ（"light" / "dark"） |
| SidebarSize | string? | サイドバーサイズ（"small" / "medium" / "large"） |

### 7.9 MenuItemDto

```csharp
public record MenuItemDto(string Area, string Page, string Label, bool IsVisible, string? Group);
```

### 7.10 監査列（全テーブル共通）

| カラム | 型 | デフォルト |
|---|---|---|
| created_at | DateTime | DateTime.UtcNow |
| created_by | string | "system" |
| updated_at | DateTime? | null |
| updated_by | string? | null |


---

## 8. CSS・UIスタイリング

モジュール側からはMainWebの静的ファイルを直接参照できないが、ランタイムではレイアウト経由で読み込み済みのため、CSSクラスやCSS変数はそのまま使用できる。

### 8.1 Bootstrap 5.3

レイアウトで Bootstrap 5.3 の CSS/JS が読み込み済み。標準クラスをそのまま使用する。

```html
<!-- ボタン -->
<button class="btn btn-primary">標準ボタン</button>
<button class="btn btn-outline-secondary">アウトラインボタン</button>

<!-- アラート -->
<div class="alert alert-success">成功メッセージ</div>

<!-- テーブル -->
<table class="table table-striped table-hover">...</table>

<!-- カード -->
<div class="card">
    <div class="card-body">
        <h5 class="card-title">タイトル</h5>
    </div>
</div>
```

### 8.2 Bootstrap Icons

Bootstrap Icons がレイアウトで読み込み済み。`<i>` タグで使用可能。

```html
<i class="bi bi-person"></i>
<i class="bi bi-search"></i>
<i class="bi bi-check-circle text-success"></i>
<button class="btn btn-primary">
    <i class="bi bi-plus-lg me-1"></i>追加
</button>
```

アイコン一覧: https://icons.getbootstrap.com/

### 8.3 カスタムカラー変数（variables.css）

MainWebの `variables.css` で100〜900の段階的なカラーCSS変数が定義されている。ランタイムで読み込み済みのため、モジュールのページやCSSで使用可能。

```css
.my-element {
    color: var(--bs-blue-700);
    background-color: var(--bs-teal-100);
    border-color: var(--bs-purple-300);
}
```

利用可能な色系統と変数名:

| 色 | 変数名パターン | 基準色（500） |
|---|---|---|
| blue | `--bs-blue-{100-900}` | `#0d6efd` |
| indigo | `--bs-indigo-{100-900}` | `#6610f2` |
| purple | `--bs-purple-{100-900}` | `#6f42c1` |
| pink | `--bs-pink-{100-900}` | `#d63384` |
| red | `--bs-red-{100-900}` | `#dc3545` |
| orange | `--bs-orange-{100-900}` | `#fd7e14` |
| yellow | `--bs-yellow-{100-900}` | `#ffc107` |
| green | `--bs-green-{100-900}` | `#198754` |
| teal | `--bs-teal-{100-900}` | `#20c997` |
| cyan | `--bs-cyan-{100-900}` | `#0dcaf0` |

### 8.4 カスタムボタンクラス

`variables.css` で追加のボタンバリアントが定義されている。Bootstrap標準の `btn-primary` 等に加えて使用可能。

```html
<!-- 塗りつぶし: btn-{color} -->
<button class="btn btn-blue">Blue</button>
<button class="btn btn-indigo">Indigo</button>
<button class="btn btn-purple">Purple</button>
<button class="btn btn-pink">Pink</button>
<button class="btn btn-red">Red</button>
<button class="btn btn-orange">Orange</button>
<button class="btn btn-yellow">Yellow</button>
<button class="btn btn-green">Green</button>
<button class="btn btn-teal">Teal</button>
<button class="btn btn-cyan">Cyan</button>

<!-- アウトライン: btn-outline-{color} -->
<button class="btn btn-outline-blue">Blue</button>
<!-- 他の色も同様 -->
```

### 8.5 サイト固有CSS変数

```css
:root {
    --oji-blue: #003da5;  /* コーポレートカラー */
}
```

### 8.6 色指定の優先順位

1. Bootstrap 5.3 標準クラス（`btn-primary`, `text-danger`, `bg-success` 等）
2. カスタムボタンクラス（`btn-blue`, `btn-outline-teal` 等）
3. カスタムCSS変数（`var(--bs-blue-500)` 等）
4. サイト固有変数（`var(--oji-blue)` 等）

### 8.7 モジュール固有のCSS

モジュール独自のCSSが必要な場合は、モジュールプロジェクト内に配置する。Razorクラスライブラリの静的ファイルは `wwwroot/` に配置し、`_content/{AssemblyName}/` パスで参照される。

```
YourModule/
└── wwwroot/
    └── css/
        └── your-module.css
```

ページでの読み込み:

```html
<link rel="stylesheet" href="~/_content/YourModule/css/your-module.css" />
```

---

## 9. Blazor Server

レイアウトで `blazor.server.js` が読み込み済み。MainWebの `Program.cs` で `AddServerSideBlazor()` / `MapBlazorHub()` が登録済みのため、モジュール内でBlazorコンポーネントを使用可能。

---

## 10. PathBase

アプリケーションは `/AuthTest` をPathBaseとして使用（IIS配置用）。

- Razor Pagesの `asp-page`, `asp-area` タグヘルパーは自動的にPathBaseを付与するため、通常は意識不要
- コード内でリダイレクトURLを構築する場合は `context.Request.PathBase.Value` を付与すること
