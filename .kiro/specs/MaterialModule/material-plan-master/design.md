# Design Document

## Overview

本設計は、予実管理（大テーマ）の **Phase 1** のみを対象とする。原材料の**月次計画**を品目別に入力・保存し、四半期・半期・年度は月次を集計して**表示専用**で示す「計画の器＋入力画面」を、既存資産に影響を与えずに追加する。

方針（要件・steering に準拠）:

- **MaterialModule 内で完結**する。`clnCoCore`（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）は不変とする。
- DB は `db_material_dev` に**新規テーブル1つ（`t_material_plans`）を追加するのみ**。既存テーブルは不変。
- 会計期（会計年度・四半期・半期）の算出は**純粋関数ヘルパ**（副作用なし）で行い、単体で property-based test の対象とする。マスタ化は将来対応。
- 画面は Razor Pages **1枚**（`Areas/Material/Pages/PlanMaster/Index`）。既存 MaterialModule の作法（`MaterialDbContext` 直接注入、`[Authorize(Policy = "DbPermissionCheck")]`、`_MaterialStyles` パーシャル、フォントサイズ統一）に準拠する。
- 集計（四半期・半期・年度）は**保存しない**。月次のみ保存し、集計は月次値の合計として都度算出・表示する。

### スコープ境界（新規追加のみ）

| 種別 | 対象 | 変更種別 |
| --- | --- | --- |
| エンティティ | `Data/Entities/TMaterialPlan.cs` | 新規 |
| DbContext | `Data/MaterialDbContext.cs` に `DbSet` と一意インデックス追加 | 変更（MaterialModule 内） |
| ヘルパ | `Services/FiscalPeriodHelper.cs`（static・純粋関数） | 新規 |
| 画面 | `Areas/Material/Pages/PlanMaster/Index.cshtml(.cs)` | 新規 |
| スキーマSQL | `docs/sql/create_t_material_plans.sql`（冪等・ユーザー適用） | 新規 |
| DI | 追加なし（ヘルパは static、ページは `MaterialDbContext` 直接注入） | 変更なし |

> DB スキーマ追加は**ユーザー承認の上、ユーザーが `db_material_dev` に適用**する。適用後、`\.kiro/docs/db/テーブル定義書.md` と `\.kiro/docs/db/ER図.md`（`t_material_plans` と `m_items` のリレーション）を更新する。

## Architecture

```
[ブラウザ] ──(GET fiscalYear, planVersion)──▶ PlanMaster/Index (PageModel)
     ▲                                              │
     │                                              ├─ IMasterService.GetActiveItemsAsync()  … 品目取得（既存サービス）
     │                                              ├─ MaterialDbContext.MaterialPlans        … 既存計画読込（AsNoTracking）
     │                                              └─ FiscalPeriodHelper                     … 列順・集計の会計期割当（純粋関数）
     │
     └──(POST 保存: 品目×月 の qty/price + row_version)──▶ OnPostSave
                                                             ├─ アップサート（一意キー）
                                                             ├─ planned_amount = qty × price
                                                             └─ 楽観ロック（row_version / DbUpdateConcurrencyException）
```

- **プレゼンテーション層**: Razor Pages 1枚。`MaterialDbContext` を Primary Constructor で直接注入（既存 `PrintSettings/Index` と同一作法）。
- **ドメイン算出層**: `FiscalPeriodHelper`（static・純粋関数）。会計年度・四半期・半期・グリッド列順を計算。DB や HTTP に依存しない。
- **データ層**: `MaterialDbContext`（既存）に `TMaterialPlan` を追加。読み取りは `AsNoTracking()`、保存はアップサート＋楽観ロック。
- **依存方向**: 画面 → ヘルパ（純粋）／画面 → DbContext。ヘルパは他層に依存しない（テスト容易）。

## Components and Interfaces

### 1. エンティティ `TMaterialPlan`（`Data/Entities/TMaterialPlan.cs`・新規）

既存エンティティ（`TStockLedger` 等）の作法に合わせ、`[Table]`／`[Column("snake_case", TypeName=...)]` を明示マッピングする。新規トランザクションテーブルのため steering ルールに従い `row_version`（`[Timestamp]`）を含める。

```csharp
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MaterialModule.Data.Entities;

/// <summary>
/// 原材料の月次計画（品目別・月次ファクト）。四半期/半期/年度は保存せず、月次の合計として都度算出する。
/// 一意キー: fiscal_year + year_month + item_id + plan_version。
/// </summary>
[Table("t_material_plans")]
public class TMaterialPlan
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    /// <summary>会計年度（4月始まり）。year_month から FiscalPeriodHelper で算出した値を保存。</summary>
    [Required]
    [Column("fiscal_year")]
    public int FiscalYear { get; set; }

    /// <summary>対象年月（例: 202604 = 2026年4月）。</summary>
    [Required]
    [Column("year_month")]
    public int YearMonth { get; set; }

    /// <summary>品目ID（m_items.id）。</summary>
    [Required]
    [Column("item_id")]
    public int ItemId { get; set; }

    /// <summary>版（annual / revised_h2 等の自由文字列）。</summary>
    [Required]
    [Column("plan_version", TypeName = "nvarchar(40)")]
    [MaxLength(40)]
    public string PlanVersion { get; set; } = string.Empty;

    /// <summary>計画数量（手入力）。</summary>
    [Required]
    [Column("planned_qty", TypeName = "decimal(18,4)")]
    public decimal PlannedQty { get; set; }

    /// <summary>計画単価（手入力）。</summary>
    [Required]
    [Column("planned_unit_price", TypeName = "decimal(18,4)")]
    public decimal PlannedUnitPrice { get; set; }

    /// <summary>計画金額（planned_qty × planned_unit_price のスナップショット）。</summary>
    [Required]
    [Column("planned_amount", TypeName = "decimal(18,4)")]
    public decimal PlannedAmount { get; set; }

    [Required]
    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [Required]
    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    /// <summary>楽観的ロック用。DB 側 ROWVERSION 自動採番。</summary>
    [Timestamp]
    [Column("row_version")]
    public byte[]? RowVersion { get; set; }

    /// <summary>品目ナビゲーション（任意・読み取り参照）。</summary>
    [ForeignKey(nameof(ItemId))]
    public MItem? Item { get; set; }
}
```

> `decimal` の桁は既存慣例が明示していないため `decimal(18,4)` を既定とする（数量・単価・金額の実運用に十分）。適用前にユーザー確認する。

### 2. DbContext 変更（`Data/MaterialDbContext.cs`）

`MaterialDbContext` は MaterialModule 内なので変更可。`DbSet` 追加と `OnModelCreating` での一意インデックス追加のみ。

```csharp
// Transaction tables に追加
public DbSet<TMaterialPlan> MaterialPlans => Set<TMaterialPlan>();

// OnModelCreating に追加（既存の命名規約 uq_{table}_01 に準拠）
modelBuilder.Entity<TMaterialPlan>()
    .HasIndex(p => new { p.FiscalYear, p.YearMonth, p.ItemId, p.PlanVersion })
    .IsUnique()
    .HasDatabaseName("uq_t_material_plans_01");
```

- 既存 DbSet・インデックス定義は変更しない（追記のみ）。
- ナビゲーション `Item` は任意参照。既存の `m_items` に対する読み取りのみで、FK 制約の追加はスキーマ SQL 側で任意（下記）。

### 3. 冪等スキーマ SQL（`docs/sql/create_t_material_plans.sql`・新規・ユーザー適用）

`db_material_dev` に対して冪等（`IF NOT EXISTS`）に作成する。`ROWVERSION`、`SYSUTCDATETIME()` 既定、一意インデックスを含む。

```sql
-- db_material_dev に適用（ユーザー実行）。冪等。
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 't_material_plans')
BEGIN
    CREATE TABLE dbo.t_material_plans
    (
        id                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_t_material_plans PRIMARY KEY,
        fiscal_year        INT            NOT NULL,
        year_month         INT            NOT NULL,   -- 例: 202604
        item_id            INT            NOT NULL,   -- m_items.id
        plan_version       NVARCHAR(40)   NOT NULL,   -- annual / revised_h2 等
        planned_qty        DECIMAL(18,4)  NOT NULL CONSTRAINT DF_t_material_plans_qty    DEFAULT (0),
        planned_unit_price DECIMAL(18,4)  NOT NULL CONSTRAINT DF_t_material_plans_price  DEFAULT (0),
        planned_amount     DECIMAL(18,4)  NOT NULL CONSTRAINT DF_t_material_plans_amount DEFAULT (0),
        created_at         DATETIME2      NOT NULL CONSTRAINT DF_t_material_plans_created DEFAULT (SYSUTCDATETIME()),
        updated_at         DATETIME2      NOT NULL CONSTRAINT DF_t_material_plans_updated DEFAULT (SYSUTCDATETIME()),
        row_version        ROWVERSION     NOT NULL
    );
END;
GO

-- 一意制約（アップサートのキー）
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'uq_t_material_plans_01')
BEGIN
    CREATE UNIQUE INDEX uq_t_material_plans_01
        ON dbo.t_material_plans (fiscal_year, year_month, item_id, plan_version);
END;
GO
```

> FK 制約（`item_id → m_items.id`）は既存 `t_orders` 等が「結果テーブル＝FK制約なし」の方針であることに合わせ、本テーブルでも**物理FKは付与しない**（EF のナビゲーションのみ）。運用整合はアプリ側で担保する。

### 4. 純粋関数ヘルパ `FiscalPeriodHelper`（`Services/FiscalPeriodHelper.cs`・static・新規）

会計年度は **4月始まり**。副作用なし・入力のみで出力が決まる純粋関数群で、property-based test の対象。

```csharp
namespace MaterialModule.Services;

/// <summary>四半期（会計年度基準）。</summary>
public enum FiscalQuarter { Q1, Q2, Q3, Q4 }

/// <summary>半期（会計年度基準）。</summary>
public enum FiscalHalf { First, Second } // First=上期(4-9), Second=下期(10-3)

/// <summary>
/// 会計期算出の純粋関数ヘルパ。会計年度は4月〜翌3月。
/// 上期=4-9、下期=10-3。四半期 Q1=4-6/Q2=7-9/Q3=10-12/Q4=1-3。
/// 副作用なし（DB/HTTP 非依存）。マスタ化は将来対応。
/// </summary>
public static class FiscalPeriodHelper
{
    /// <summary>year_month(例:202604) から会計年度を算出。1-3月は暦年-1、4-12月は暦年。</summary>
    public static int GetFiscalYear(int yearMonth)
    {
        int year = yearMonth / 100;
        int month = yearMonth % 100;
        ValidateMonth(month);
        return month <= 3 ? year - 1 : year;
    }

    /// <summary>月(1-12) から四半期を算出。Q1=4-6/Q2=7-9/Q3=10-12/Q4=1-3。</summary>
    public static FiscalQuarter GetQuarter(int month)
    {
        ValidateMonth(month);
        return month switch
        {
            >= 4 and <= 6   => FiscalQuarter.Q1,
            >= 7 and <= 9   => FiscalQuarter.Q2,
            >= 10 and <= 12 => FiscalQuarter.Q3,
            _               => FiscalQuarter.Q4, // 1-3
        };
    }

    /// <summary>月(1-12) から半期を算出。上期=4-9/下期=10-3。</summary>
    public static FiscalHalf GetHalf(int month)
    {
        ValidateMonth(month);
        return (month >= 4 && month <= 9) ? FiscalHalf.First : FiscalHalf.Second;
    }

    /// <summary>グリッド列順を算出。4月=1 … 翌3月=12。</summary>
    public static int GetFiscalMonthOrder(int month)
    {
        ValidateMonth(month);
        return month >= 4 ? month - 3 : month + 9; // 4→1..12→9, 1→10..3→12
    }

    /// <summary>月が1-12外なら例外。</summary>
    private static void ValidateMonth(int month)
    {
        if (month < 1 || month > 12)
        {
            throw new ArgumentOutOfRangeException(
                nameof(month), month, "月は1〜12の範囲で指定してください。");
        }
    }
}
```

インターフェース要約:

| メソッド | 入力 | 出力 | 規則 |
| --- | --- | --- | --- |
| `GetFiscalYear(int yearMonth)` | 例:202604 | int | 月1-3→暦年-1、月4-12→暦年 |
| `GetQuarter(int month)` | 1-12 | `FiscalQuarter` | Q1=4-6/Q2=7-9/Q3=10-12/Q4=1-3 |
| `GetHalf(int month)` | 1-12 | `FiscalHalf` | 上期4-9/下期10-3 |
| `GetFiscalMonthOrder(int month)` | 1-12 | 1-12 | 4月=1 … 翌3月=12 |
| （共通）不正月 | 1-12外 | 例外 | `ArgumentOutOfRangeException` |

### 5. 計画入力ページ `PlanMaster/Index`（`.cshtml` ＋ `.cshtml.cs`・新規）

既存 `PrintSettings/Index` と同じく `[Authorize(Policy = "DbPermissionCheck")]` を付与し、`MaterialDbContext` を Primary Constructor で直接注入する。

#### PageModel 概要

```csharp
[Authorize(Policy = "DbPermissionCheck")]
public class IndexModel(
    MaterialDbContext context,
    IMasterService masterService) : PageModel
{
    [BindProperty(SupportsGet = true)] public int FiscalYear { get; set; }
    [BindProperty(SupportsGet = true)] public string PlanVersion { get; set; } = "annual";

    public List<PlanRow> Rows { get; private set; } = [];

    public async Task OnGetAsync() { /* 品目取得＋既存計画読込＋グリッド構築 */ }

    public async Task<IActionResult> OnPostSaveAsync(PlanSaveRequest req) { /* アップサート＋楽観ロック */ }
}
```

- **`OnGetAsync(fiscalYear, planVersion)`**:
  1. `IMasterService.GetActiveItemsAsync()` で対象品目を取得（既存の品目取得方法に準拠）。
  2. `context.MaterialPlans.AsNoTracking()` で対象（`FiscalYear` ＋ `PlanVersion`）の既存計画を読込。
  3. 品目×12ヶ月グリッドを構築。列順は `FiscalPeriodHelper.GetFiscalMonthOrder` で 4月→翌3月。未入力セルは空。
  4. 各行の `row_version`（Base64）をクライアントへ返却（楽観ロック用）。

- **グリッド**:
  - 行＝品目、列＝4月〜翌3月（12列）＋ Q1〜Q4・上期・下期・年度合計（集計は**表示専用**）。
  - 各月セルは数量・単価を入力。金額＝数量×単価をクライアント（vanilla JS）で即時再計算表示。
  - 集計（Q/半期/年度）は月次値の合計を JS で算出し表示専用。会計期の割当は `FiscalPeriodHelper` の規則に一致。

- **`OnPostSaveAsync`（保存＝アップサート）**:
  1. 送信された品目×月の `qty`/`price` と各行 `row_version` を受領。
  2. 一意キー（`fiscal_year + year_month + item_id + plan_version`）で既存行を検索。
     - 存在すれば更新（`updated_at` 更新）。無ければ挿入（`created_at`/`updated_at` 設定）。
  3. `planned_amount = planned_qty × planned_unit_price` を保存。
  4. `fiscal_year` は `FiscalPeriodHelper.GetFiscalYear(year_month)` で決定（画面選択の年度と整合）。
  5. 楽観ロック: 受領 `row_version` を `Entry(entity).OriginalValues` に適用し `SaveChangesAsync`。`DbUpdateConcurrencyException` を捕捉し競合メッセージを返す。成功時は更新後 `row_version` を返却。

- **版切替**: `PlanVersion` は `annual` / `revised_h2` を切替（将来 `forecast` 等を追加可能）。
- **デザイン準拠**: ページ先頭に `<partial name="_MaterialStyles" />`。コンテナ `class="container-fluid mt-3 px-4 material-page" style="font-size: 0.8rem;"`、タイトル `<h5 class="mb-2">@ViewData["Title"]</h5>`、グリッドテーブル `style="font-size: 0.75rem;"`。

#### 画面用モデル（`Areas/Material/Pages/PlanMaster` 直下 or `Models/ViewModels`）

```csharp
/// <summary>グリッド1行（品目1件＋12ヶ月分のセル）。</summary>
public record PlanRow(int ItemId, string ItemCode, string ItemName, PlanCell[] Months);

/// <summary>月次セル（会計月順・数量・単価・金額・楽観ロック値）。</summary>
public record PlanCell(int YearMonth, decimal Qty, decimal UnitPrice, decimal Amount, string? RowVersionBase64);

/// <summary>保存要求（品目×月のフラットな明細）。</summary>
public record PlanSaveRequest(int FiscalYear, string PlanVersion, PlanSaveCell[] Cells);
public record PlanSaveCell(int ItemId, int YearMonth, decimal Qty, decimal UnitPrice, string? RowVersionBase64);
```

### 6. DI（変更なし）

- 新規サービス登録は不要。`FiscalPeriodHelper` は static、ページは `MaterialDbContext` を直接注入（既存 `AddMaterialModule` に変更なし）。
- `clnCoCore`（MainWeb 等）への登録・設定追加は行わない。

## Data Models

### t_material_plans（新規・`db_material_dev`）

| 列名 | 型 | Null | 既定 | 説明 |
| --- | --- | --- | --- | --- |
| id | INT IDENTITY (PK) | NOT NULL | | 主キー |
| fiscal_year | INT | NOT NULL | | 会計年度（4月始まり） |
| year_month | INT | NOT NULL | | 対象年月（例: 202604） |
| item_id | INT | NOT NULL | | 品目ID（m_items.id・物理FKなし） |
| plan_version | NVARCHAR(40) | NOT NULL | | 版（annual / revised_h2 等） |
| planned_qty | DECIMAL(18,4) | NOT NULL | 0 | 計画数量 |
| planned_unit_price | DECIMAL(18,4) | NOT NULL | 0 | 計画単価 |
| planned_amount | DECIMAL(18,4) | NOT NULL | 0 | 計画金額（数量×単価のスナップショット） |
| created_at | DATETIME2 | NOT NULL | SYSUTCDATETIME() | 作成日時 |
| updated_at | DATETIME2 | NOT NULL | SYSUTCDATETIME() | 更新日時 |
| row_version | ROWVERSION | NOT NULL | 自動 | 楽観ロック用 |

- **一意制約**: `uq_t_material_plans_01 = (fiscal_year, year_month, item_id, plan_version)`。
- **集計は非保存**: 四半期・半期・年度合計は列として持たず、月次値の合計として都度算出（要件3.4/3.5）。
- **既存テーブルは不変**: `m_items`・`m_purchase_conditions` 等は参照のみ。`m_purchase_conditions` は本 Phase では未使用でも可、参照する場合も読み取りのみ。

## Error Handling

| ケース | 発生源 | 挙動 |
| --- | --- | --- |
| 数値以外の入力（数量・単価） | クライアント（vanilla JS）＋サーバ型変換 | 入力を受理せず「入力値が不正です」を表示。保存要求に含めない。 |
| 月が 1-12 の範囲外 | `FiscalPeriodHelper.ValidateMonth` | `ArgumentOutOfRangeException`（プログラム不整合の検出）。 |
| year_month の桁不正（月抽出が範囲外） | `GetFiscalYear` 内 `ValidateMonth` | 同上。呼び出し側は正しい year_month を渡す前提。 |
| 楽観ロック競合（row_version 不一致） | `SaveChangesAsync` → `DbUpdateConcurrencyException` | 保存を中止し「他のユーザーが先に更新しました。画面を再読み込みしてください。」を返す（steering 規定文言）。 |
| 認可なし | `[Authorize(Policy = "DbPermissionCheck")]` | アクセス拒否。 |

- ログは日本語・構造化ログ（`{Placeholder}`）。競合・不正入力は Warning、想定外例外は Error（ログ出力後 `throw;`）。

## Testing Strategy

**二層アプローチ**:

- **プロパティテスト（PBT）**: 純粋関数 `FiscalPeriodHelper` を対象。会計期算出の普遍規則を全月域で検証。xUnit + FsCheck.Xunit、**最低100反復**、`Prop.ForAll` は最大3 Arbitrary。テストタグ `Feature: material-plan-master, Property N`。テストクラス名 `FiscalPeriodHelperPropertyTests`。
- **代表例／統合テスト（任意）**: 保存アップサート・楽観ロック・画面集計は DB/UI 副作用に依存するため、代表例または統合テストで検証する（InMemory DB は `Guid.NewGuid()` で一意名・`IDisposable` 破棄）。100反復の価値が薄いため PBT 対象外。
  - アップサート: 新規挿入／既存更新／`planned_amount = qty × price`／`created_at`・`updated_at` 設定（要件4）。
  - 楽観ロック: 古い `row_version` 保存で競合メッセージ（要件5）。
  - 画面集計: 代表データで Q合計・半期合計・年度合計が対象月次の総和に一致（要件3、将来 純粋集計関数を抽出すれば PBT 化可能）。

**プロパティテスト構成**:
- 最低100反復／プロパティ。
- 各プロパティは設計の Property 番号を参照。
- ジェネレータで不正月（1-12外）・境界月（3/4/9/10/12/1）を確実にカバーする。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

本 Phase の property-based test 対象は純粋関数 `FiscalPeriodHelper`（要件1）とする。要件2〜7（入力保持・集計表示・保存・楽観ロック・認可・デザイン）は UI/DB/設定に依存するため、代表例・統合テスト・設計レビューで担保する（Testing Strategy 参照）。

### Property 1: 会計年度算出の全域整合

*For any* 有効な year_month（月成分が 1〜12）について、`GetFiscalYear` は、月が 1〜3 のとき暦年（year_month / 100）から 1 を減じた値を返し、月が 4〜12 のとき暦年をそのまま返す。

**Validates: Requirements 1.1, 1.2**

### Property 2: 四半期分類の全域写像

*For any* 月 m（1〜12）について、`GetQuarter(m)` は、m が 4〜6 のとき Q1、7〜9 のとき Q2、10〜12 のとき Q3、1〜3 のとき Q4 をちょうど1つ返す（全月がいずれか単一の四半期に正しく割り当てられる）。

**Validates: Requirements 1.3, 1.4, 1.5, 1.6**

### Property 3: 半期の完全分割

*For any* 月 m（1〜12）について、`GetHalf(m)` は、m が 4〜9 のとき上期（First）、それ以外（10〜12 および 1〜3）のとき下期（Second）を返す（上期と下期は排他かつ 1〜12 を網羅する）。

**Validates: Requirements 1.7, 1.8**

### Property 4: 範囲外の月はエラー

*For any* 月成分が 1〜12 の範囲外である入力について、`GetFiscalYear` / `GetQuarter` / `GetHalf` / `GetFiscalMonthOrder` は入力値が不正である旨の例外（`ArgumentOutOfRangeException`）を返す。

**Validates: Requirements 1.9**
