# Design Document

## Overview

発注エントリ画面（`Areas/Material/Pages/Orders/Create`）の登録モーダルにある出力区分セレクトの既定値を、現在のハードコード「3（印刷/FAX）」から、ログインユーザーごとに設定可能な「既定出力区分（Default_Output_Type）」に置き換える。設定は既存の自己サービス画面 `Areas/Material/Pages/PrintSettings/Index` に集約し、保持先として新規マスタ `m_user_order_setting`（1ユーザー1行）を用いる。未設定・不正値は現行踏襲で「3」にフォールバックする。

本機能は MaterialModule 内で完結する（clnCoCore＝MainWeb / AuthModule / SharedCore は変更しない）。既存の発注登録・保存挙動は、モーダルの初期表示以外について一切変更しない。

### 設計方針（確定事項の要約）

- 新規エンティティ `MUserOrderSetting`（Table: `m_user_order_setting`）を追加。`MUserPrintSetting` の規約に厳密に倣う（`id` IDENTITY 主キー ＋ `user_code` 一意インデックス、`created_at`/`updated_at`、`row_version`[Timestamp]）。要件の「user_code を主キー相当・一意」は、既存作法に合わせ「id 代理主キー＋user_code の一意インデックス」で満たす。
- 冪等スキーマSQL `MaterialModule/docs/sql/create_m_user_order_setting.sql` を追加（`create_m_user_print_setting.sql` の書式に準拠）。
- 出力区分の値域判定・フォールバックを純粋関数（静的ヘルパ `OutputTypeHelper`）に切り出し、PBT 対象とする。
- 読み取り／保存（アップサート）を小さなサービス `IUserOrderSettingService` に集約し、両ページから共有する（`IUserPreferenceService` と同じ public interface + internal 実装 + DI 登録の作法）。
- `PrintSettings/Index` に「既定出力区分」select を追加。保存は本人の `m_user_order_setting` をアップサート（未設定は行なし → 保存時に作成）。値域バリデーション・楽観的ロック・競合メッセージを既存作法どおり実装する。
- `Orders/Create` の OnGet でログインユーザーの既定を解決し、`Order.OutputType` に設定してビューへ渡す（`asp-for` の初期選択に反映）。既存の個別編集行・登録処理は不変。

## Architecture

### コンポーネント関連

```
[PrintSettings/Index]  ──(表示: 初期選択の解決)──▶ OutputTypeHelper.Normalize
        │  (保存: 値域検証 → アップサート)
        ▼
[IUserOrderSettingService] ──▶ MaterialDbContext.UserOrderSettings ──▶ m_user_order_setting
        ▲
        │  (表示: 既定の読み取り → Normalize → Order.OutputType)
[Orders/Create (OnGet)]

[Orders/Create.cshtml モーダル select] ─ asp-for="Order.OutputType"（初期選択＝解決済み既定）
```

- 表示系（`Orders/Create` 初期表示、`PrintSettings` 初期表示）は「保存済み生値（int?）→ `OutputTypeHelper.Normalize` → 表示値」の一方向。未設定/不正は 3 に丸める。
- 保存系（`PrintSettings` 保存）は「入力値の値域検証（不正は拒否）→ アップサート」。表示のフォールバックとは分離する（不正入力は黙って丸めず、拒否してメッセージ表示）。

### レイヤと責務

| レイヤ | 型 | 責務 |
|---|---|---|
| Domain(pure) | `OutputTypeHelper` (static) | 値域判定・フォールバックの純粋関数。DB非依存で単体/プロパティテスト対象。 |
| Service | `IUserOrderSettingService` / `UserOrderSettingService` | 本人の既定出力区分の読み取り・アップサート（楽観的ロック）。 |
| Data | `MUserOrderSetting` / `MaterialDbContext` | エンティティ・一意制約。 |
| UI | `PrintSettings/Index`（設定）、`Orders/Create`（初期表示） | 表示・入力・保存・メッセージ。 |

## Components and Interfaces

### 1. 純粋ヘルパ `OutputTypeHelper`（新規）

配置: `MaterialModule/Services/OutputTypeHelper.cs`

```csharp
namespace MaterialModule.Services;

/// <summary>
/// 出力区分（0=出力なし/1=印刷/2=FAX/3=印刷/FAX）の値域判定とフォールバックを担う純粋ヘルパ。
/// DBやHTTPに依存しないため、単体・プロパティベーステストの対象とする。
/// </summary>
public static class OutputTypeHelper
{
    /// <summary>フォールバック既定値（印刷/FAX）。</summary>
    public const int Fallback = 3;

    /// <summary>出力区分として有効か（0/1/2/3 のいずれか）。</summary>
    public static bool IsValid(int? value) => value is 0 or 1 or 2 or 3;

    /// <summary>
    /// 表示用の既定出力区分を解決する。値が 0/1/2/3 ならそのまま、
    /// null または範囲外なら <see cref="Fallback"/>（3）を返す。戻り値は必ず 0/1/2/3。
    /// </summary>
    public static int Normalize(int? value) => IsValid(value) ? value!.Value : Fallback;
}
```

- `Normalize` は Req 1.1/1.2/1.3、3.2/3.3 の「初期選択値の決定」を一元化する。
- `IsValid` は Req 2.2/3.5 の「保存時の値域検証」に用いる。

### 2. サービス `IUserOrderSettingService`（新規）

配置: `MaterialModule/Services/IUserOrderSettingService.cs`（public interface）、`UserOrderSettingService.cs`（internal 実装）。作法は `IUserPreferenceService`/`UserPreferenceService` に倣う。

```csharp
namespace MaterialModule.Services;

public interface IUserOrderSettingService
{
    /// <summary>本人の既定出力区分の「生値」を返す（未設定は null、範囲外はそのまま返す）。</summary>
    Task<int?> GetDefaultOutputTypeAsync(string userCode);

    /// <summary>
    /// 本人の既定出力区分をアップサートする（未設定は新規作成、既存は更新）。
    /// 値域検証は呼び出し側（ページ）で行う前提だが、実装側でも <see cref="OutputTypeHelper.IsValid"/> を満たさない値は
    /// ArgumentOutOfRangeException を投げて防御する。競合は DbUpdateConcurrencyException として呼び出し側へ伝播する。
    /// </summary>
    Task SaveDefaultOutputTypeAsync(string userCode, int outputType);
}
```

実装（`UserOrderSettingService`）の要点:

```csharp
internal class UserOrderSettingService(MaterialDbContext context) : IUserOrderSettingService
{
    public async Task<int?> GetDefaultOutputTypeAsync(string userCode)
    {
        MUserOrderSetting? row = await context.UserOrderSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.UserCode == userCode);
        return row?.DefaultOutputType;
    }

    public async Task SaveDefaultOutputTypeAsync(string userCode, int outputType)
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
                CreatedAt = now,
                UpdatedAt = now,
            });
        }
        else if (row.DefaultOutputType != outputType)
        {
            row.DefaultOutputType = outputType;
            row.UpdatedAt = now;
        }

        await context.SaveChangesAsync(); // DbUpdateConcurrencyException は呼び出し側で捕捉
    }
}
```

DI 登録（`MaterialModuleExtensions.AddMaterialModule`）:

```csharp
services.AddScoped<IUserOrderSettingService, UserOrderSettingService>();
```

### 3. エンティティ `MUserOrderSetting`（新規）

配置: `MaterialModule/Data/Entities/MUserOrderSetting.cs`。`MUserPrintSetting` の規約に厳密準拠。

```csharp
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MaterialModule.Data.Entities;

/// <summary>
/// ユーザー発注設定（m_user_order_setting）。ユーザーごとに 1 行、既定の出力区分
/// （0=出力なし/1=印刷/2=FAX/3=印刷/FAX）を保持する。自己サービス画面で本人が設定する。
/// user_code を一意とする。多人数同時更新に備え row_version で楽観的ロック。
/// </summary>
[Table("m_user_order_setting")]
public class MUserOrderSetting
{
    [Key]
    [Column("id")]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    /// <summary>ユーザーコード（ログイン名。t_orders.user_id 相当）。</summary>
    [Required]
    [Column("user_code")]
    [MaxLength(40)]
    public string UserCode { get; set; } = string.Empty;

    /// <summary>既定の出力区分（0/1/2/3）。</summary>
    [Required]
    [Column("default_output_type")]
    public int DefaultOutputType { get; set; }

    [Required]
    [Column("created_at")]
    public DateTime CreatedAt { get; set; }

    [Required]
    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; }

    [Timestamp]
    [Column("row_version")]
    public byte[] RowVersion { get; set; } = [];
}
```

`MaterialDbContext` への追加:

```csharp
// マスタ DbSet 群に追記
public DbSet<MUserOrderSetting> UserOrderSettings => Set<MUserOrderSetting>();

// OnModelCreating の一意制約群に追記
modelBuilder.Entity<MUserOrderSetting>()
    .HasIndex(s => s.UserCode)
    .IsUnique()
    .HasDatabaseName("uq_m_user_order_setting_01");
```

### 4. 冪等スキーマSQL（新規）

配置: `MaterialModule/docs/sql/create_m_user_order_setting.sql`。`create_m_user_print_setting.sql` の書式に準拠（`USE db_material_dev; GO`、`IF NOT EXISTS` によるテーブル/インデックスの冪等作成、`ROWVERSION`、`SYSUTCDATETIME()` 既定）。

```sql
USE db_material_dev;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'm_user_order_setting')
BEGIN
    CREATE TABLE dbo.m_user_order_setting
    (
        id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_m_user_order_setting PRIMARY KEY,
        user_code           NVARCHAR(40) NOT NULL,
        default_output_type INT          NOT NULL,
        created_at          DATETIME     NOT NULL CONSTRAINT DF_m_user_order_setting_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at          DATETIME     NOT NULL CONSTRAINT DF_m_user_order_setting_updated_at DEFAULT (SYSUTCDATETIME()),
        row_version         ROWVERSION   NOT NULL
    );
    PRINT 'Created table m_user_order_setting';
END
ELSE
    PRINT 'Skip create (m_user_order_setting already exists).';
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'uq_m_user_order_setting_01')
BEGIN
    CREATE UNIQUE INDEX uq_m_user_order_setting_01
        ON dbo.m_user_order_setting (user_code);
    PRINT 'Created unique index uq_m_user_order_setting_01';
END
ELSE
    PRINT 'Skip index (uq_m_user_order_setting_01 already exists).';
GO
```

> 補足: 値域（0/1/2/3）はアプリ側検証で担保する（`create_m_user_print_setting.sql` が CHECK 制約を持たない既存作法に合わせ、SQL 側 CHECK 制約は付与しない）。

### 5. `PrintSettings/Index`（既存改修）

`IndexModel` に `IUserOrderSettingService` を DI 追加（primary constructor に引数追加）。既存の印刷設定ロジックには手を加えない。

- 新規プロパティ:
  ```csharp
  [BindProperty]
  public int DefaultOutputType { get; set; }   // select のバインド先（0/1/2/3）
  ```
- `OnGetAsync` 末尾で本人の既定を解決:
  ```csharp
  DefaultOutputType = OutputTypeHelper.Normalize(
      await orderSettingService.GetDefaultOutputTypeAsync(userCode));   // Req 3.2/3.3
  ```
- 保存ハンドラ: 既存の `OnPostAsync`（印刷設定保存）とは分離した専用ハンドラ `OnPostSaveOrderSettingAsync` を追加（責務分離。既存の保存挙動を変えない）。
  ```csharp
  public async Task<IActionResult> OnPostSaveOrderSettingAsync()
  {
      string userCode = User.Identity?.Name ?? "unknown";

      if (!OutputTypeHelper.IsValid(DefaultOutputType))          // Req 3.5
      {
          Message = "出力区分の値が不正です。0〜3 のいずれかを選択してください。";
          await ReloadAsync(userCode);
          DefaultOutputType = OutputTypeHelper.Normalize(
              await orderSettingService.GetDefaultOutputTypeAsync(userCode));
          return Page();
      }

      try
      {
          await orderSettingService.SaveDefaultOutputTypeAsync(userCode, DefaultOutputType);  // Req 3.4
          Message = "既定出力区分を保存しました。";
      }
      catch (DbUpdateConcurrencyException)                        // Req 3.6
      {
          Message = "他のユーザーが先に更新しました。画面を再読み込みしてください。";
      }

      await ReloadAsync(userCode);
      DefaultOutputType = OutputTypeHelper.Normalize(
          await orderSettingService.GetDefaultOutputTypeAsync(userCode));
      return Page();
  }
  ```
- ビュー（`Index.cshtml`）: 既存フォームとは別の小さなカード＋独立フォーム（`asp-page-handler="SaveOrderSetting"`）で「既定出力区分」select を追加。選択肢は 0/1/2/3。`_MaterialStyles` とフォント規約は既存に準拠（追加要素は既存コンテナ内、`font-size: 0.75rem` 系のトーンを踏襲）。
  ```html
  <div class="card mt-2">
      <div class="card-header py-1">発注エントリ 既定出力区分</div>
      <div class="card-body">
          <form method="post" asp-page-handler="SaveOrderSetting" class="d-flex align-items-end gap-2">
              <div>
                  <label asp-for="DefaultOutputType" class="form-label mb-0">既定の出力区分</label>
                  <select asp-for="DefaultOutputType" class="form-select form-select-sm" style="width:auto;">
                      <option value="0">出力なし</option>
                      <option value="1">印刷</option>
                      <option value="2">FAX</option>
                      <option value="3">印刷/FAX</option>
                  </select>
              </div>
              <button type="submit" class="btn btn-primary btn-sm"><i class="bi bi-save"></i> 保存</button>
          </form>
          <div class="form-text" style="font-size: 0.7rem;">
              ※ 発注エントリの登録モーダルを開いたときの出力区分の初期選択に使用します。
          </div>
      </div>
  </div>
  ```
  `asp-for="DefaultOutputType"` により、`OnGet`/`OnPost` で設定した値に応じて該当 option が自動選択される（Req 3.2/3.3）。

### 6. `Orders/Create`（既存改修：初期表示のみ）

`CreateModel` に `IUserOrderSettingService` を DI 追加（primary constructor に引数追加）。

- 解決した既定値を保持する読み取り用プロパティを追加:
  ```csharp
  public int DefaultOutputType { get; private set; } = OutputTypeHelper.Fallback;
  ```
- `LoadPageDataAsync`（全ハンドラ経由で呼ばれる）で既定を解決:
  ```csharp
  DefaultOutputType = OutputTypeHelper.Normalize(
      await orderSettingService.GetDefaultOutputTypeAsync(userId));   // Req 1.1/1.2/1.3
  ```
- モーダルの初期選択は `Order.OutputType` にバインドされるため、「`Order` を新規生成する箇所」で既定を適用する:
  - `OnGetAsync`: `LoadPageDataAsync` 後に `Order.OutputType ??= DefaultOutputType;`
  - 追加成功後の `Order = new OrderCreateDto();`（`OnPostAddAsync`）と `OnPostEditEntryAsync` 末尾の `Order = new OrderCreateDto();` の直後に `Order.OutputType = DefaultOutputType;`
  - バリデーションエラーで再表示する場合は `Order`（モデルバインド値）をそのまま保持する（ユーザーの選択を尊重）。
- ビュー（`Create.cshtml`）モーダルの select を、ハードコード `selected` から `asp-for` 駆動に変更する（既存の編集行 select と同じく値一致で選択）。あわせて、モーダルを開くたびに既定へ戻すため `data-default-output` を付与し、`resetEntryForm()` で反映する:
  ```html
  <select asp-for="Order.OutputType" class="form-select form-select-sm"
          id="outputTypeSelect" data-default-output="@Model.DefaultOutputType">
      <option value="0">出力なし</option>
      <option value="1">印刷</option>
      <option value="2">FAX</option>
      <option value="3">印刷/FAX</option>
  </select>
  ```
  ```js
  // resetEntryForm() 内に追記（モーダルを開くたびに既定へ戻す：Req 1.1/1.2）
  var outputSel = document.getElementById('outputTypeSelect');
  if (outputSel) outputSel.value = outputSel.dataset.defaultOutput;
  ```
- 変更後の値の保持（Req 1.4）と既存の登録・保存挙動（Req 1.5）は不変。個別編集行の select（`entry.OutputType`）・`OnPostAddAsync` の `AddEntryAsync` 呼び出しには手を加えない。

## Data Models

### m_user_order_setting

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | INT IDENTITY | PK | 代理主キー |
| user_code | NVARCHAR(40) | NOT NULL, UNIQUE(uq_m_user_order_setting_01) | ユーザーコード（1ユーザー1行） |
| default_output_type | INT | NOT NULL | 既定出力区分（0/1/2/3、値域はアプリ検証） |
| created_at | DATETIME | NOT NULL, DEFAULT SYSUTCDATETIME() | 作成時刻 |
| updated_at | DATETIME | NOT NULL, DEFAULT SYSUTCDATETIME() | 更新時刻 |
| row_version | ROWVERSION | NOT NULL | 楽観的ロック用 |

出力区分コードの意味（`Output_Type`）: 0=出力なし / 1=印刷 / 2=FAX / 3=印刷/FAX。

## Error Handling

| 事象 | 箇所 | 挙動 |
|---|---|---|
| 保存値が 0/1/2/3 以外 | `PrintSettings.OnPostSaveOrderSettingAsync` | 保存せず「出力区分の値が不正です。0〜3 のいずれかを選択してください。」を表示（Req 3.5）。サービス側は防御的に `ArgumentOutOfRangeException`。 |
| 楽観的ロック競合 | `PrintSettings.OnPostSaveOrderSettingAsync` | `DbUpdateConcurrencyException` を捕捉し「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示（Req 3.6）。 |
| 既定が未設定 | 表示系（Create/PrintSettings） | `GetDefaultOutputTypeAsync` が null → `Normalize` で 3（Req 1.2/3.3）。 |
| 既定が範囲外（データ不整合） | 表示系 | `Normalize` で 3 にフォールバック（Req 1.3）。保存経路では発生しない（検証済み）が、防御として表示側で吸収。 |

## Testing Strategy

- **プロパティテスト（FsCheck.Xunit, 最低100反復）**: `OutputTypeHelper` の純粋関数を中心に検証。テストクラス `OutputTypeHelperPropertyTests`。
- **モデルベース/ラウンドトリップ**: `UserOrderSettingService` を InMemory DB（`Guid.NewGuid()` でDB名一意・`IDisposable` 破棄）で検証。保存→読取の往復と単一行性。
- **例外/エッジ（例示テスト）**: 値域外拒否メッセージ、競合メッセージ、初期表示の未設定フォールバック、既存登録挙動の非回帰。
- 各プロパティテストは対応する設計プロパティ番号を `Feature: orders-default-output-type, Property {n}: {text}` 形式でタグ付けする。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 出力区分の正規化（値域・忠実性・フォールバック）

*For any* `int?` 入力値について、`OutputTypeHelper.Normalize` の戻り値は必ず {0,1,2,3} のいずれかであり、入力が {0,1,2,3} のときは入力値をそのまま返し、null または {0,1,2,3} 以外のときは 3 を返す。

**Validates: Requirements 1.1, 1.2, 1.3, 3.2, 3.3**

### Property 2: 保存の往復と単一行性（有効値）

*For any* ユーザーコードと {0,1,2,3} の任意の値 v について、`SaveDefaultOutputTypeAsync(userCode, v)` を（1回以上、同一ユーザーで）実行した後に `GetDefaultOutputTypeAsync(userCode)` を呼ぶと v が返り、当該ユーザーの行は常にちょうど 1 行である。

**Validates: Requirements 2.1, 3.4**

### Property 3: 不正値の拒否（状態不変）

*For any* {0,1,2,3} に含まれない `int` 値について、保存経路は当該値を拒否し（`OutputTypeHelper.IsValid` は false を返し、保存は行われない）、`m_user_order_setting` の状態は変更されない。

**Validates: Requirements 2.2, 3.5**
