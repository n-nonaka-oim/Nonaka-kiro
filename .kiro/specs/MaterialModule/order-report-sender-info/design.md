# 設計書

## はじめに

発注書兼納入依頼書 PDF の発注元情報を、発注者本人の SharedCore 情報（`ApplicationUser`＋主所属 `Section`）から取得し、空白/NULL 項目は補完マスタ `m_general_personal_info`（旧 `m_company_info`）へフィールド単位でフォールバックする。認証基盤（dbAuthTest）へは直接アクセスせず、SharedCore の抽象（`UserManager<ApplicationUser>` / `IUserRepository`）経由でのみ取得する。あわせて補完マスタを改名し `email` 列を追加、発注承認送信の差出人アドレス未設定時のフォールバックに用いる。

本改修は MaterialModule 内で完結する。clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure）は読み取り参照のみ。

## アーキテクチャ

### 取得経路（直接DBアクセス禁止）

```
発注書PDF / 発注承認送信
        │  order.UserId（＝ログイン名）
        ▼
ISenderInfoResolver（MaterialModule・新規）
        ├─ UserManager<ApplicationUser>.FindByNameAsync(loginName)  → ApplicationUser（郵便/住所/TEL/FAX/担当/Email）
        ├─ IUserRepository.GetMainUserSectionAsync(user.Id)         → Section（会社=Company / 工場=Office）
        └─ IMasterService.GetGeneralPersonalInfoAsync(loginName)    → MGeneralPersonalInfo（補完マスタ・db_material_dev）
        ▼
SenderInfoMerger.Merge(...)（純粋ロジック・PBT対象）
        ▼
SenderInfo（会社名/工場名/郵便/住所/TEL/FAX/担当/受入工場）
```

- MaterialModule は dbAuthTest への DbContext・接続文字列を持たない。SharedCore の `UserManager`/`IUserRepository` は MainWeb の DI（`AddSharedInfrastructure`）で解決される（ランタイムホスト）。
- 補完マスタは MaterialModule 自身の `MaterialDbContext`（db_material_dev）。

### 影響コンポーネント

| コンポーネント | 変更内容 |
|---|---|
| `Data/Entities/MCompanyInfo.cs` | `MGeneralPersonalInfo` へ改名・`[Table("m_general_personal_info")]`・`Email` 追加 |
| `Data/MaterialDbContext.cs` | `DbSet<MGeneralPersonalInfo> GeneralPersonalInfos`（旧 `CompanyInfos`） |
| `Services/IMasterService.cs` / `MasterService.cs` | `GetCompanyInfoAsync` → `GetGeneralPersonalInfoAsync`（戻り値 `MGeneralPersonalInfo`） |
| `Services/ISenderInfoResolver.cs` / `SenderInfoResolver.cs`（新規） | SharedCore＋マスタから `SenderInfo` を解決 |
| `Models/Dtos/SenderInfo.cs`（新規） | 発注元情報 DTO |
| `Logic/SenderInfoMerger.cs`（新規・静的/純粋） | フィールド単位フォールバックのマージ（PBT対象） |
| `Services/OrderPdfService.cs` | `ISenderInfoResolver` を注入し `SenderInfo` を印字 |
| `Services/DispatchEnqueueService.cs` | 差出人フォールバックに発注者 Email を挿入・`GetGeneralPersonalInfoAsync` へ追随 |
| `Extensions/MaterialModuleExtensions.cs` | `ISenderInfoResolver` の DI 登録 |

## データモデル

### MGeneralPersonalInfo（旧 MCompanyInfo）

```csharp
[Table("m_general_personal_info")]
public class MGeneralPersonalInfo
{
    // 既存列は維持（id, user_code, simple_name, company_name_1, department_name_1,
    // company_name_2, department_name_2, zip_code, address_1, address_2, tel, fax,
    // is_active, created_at, updated_at）

    [Column("email")]
    [MaxLength(256)]
    public string? Email { get; set; }   // 追加
}
```

- DBスキーマ変更 SQL（ユーザー適用）: `MaterialModule/docs/sql/rename_m_company_info_to_general_personal_info.sql`
  - `EXEC sp_rename 'm_company_info', 'm_general_personal_info';`
  - `ALTER TABLE m_general_personal_info ADD email nvarchar(256) NULL;`

### SenderInfo（新規 DTO・発注元情報）

```csharp
public sealed record SenderInfo(
    string? CompanyName,     // 会社名  ← Section.Company / company_name_1
    string? FactoryName,     // 工場名  ← Section.Office / department_name_1
    string? DepartmentSub,   // 部署補足 ← company/department_name_2（マスタのみ・従来維持）
    string? ZipCode,         // 郵便    ← ApplicationUser.PostalCode / zip_code
    string? Address,         // 住所    ← ApplicationUser.Address / address_1
    string? Tel,             // TEL     ← ApplicationUser.PhoneNumber / tel
    string? Fax,             // FAX     ← ApplicationUser.FaxNumber / fax
    string? Contact,         // 担当    ← ApplicationUser.LastName / t_orders スナップショット
    string? ReceivingFactory // 受入工場 ← simple_name（従来維持）
);
```

## コンポーネント設計

### SenderInfoMerger（純粋ロジック・PBT対象）

フィールド単位フォールバックのマージのみを担う静的メソッド。I/O 非依存で単体・プロパティテスト可能。

```csharp
internal static class SenderInfoMerger
{
    // 非空（trim後 空でない）ならそれを、なければ次候補。independentに各項目を解決。
    internal static string? Coalesce(params string?[] candidates)
        => candidates.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c));

    // user/section が null（未解決）でも安全に動作する（全項目マスタ＋担当スナップショットへ）
    internal static SenderInfo Merge(
        ApplicationUser? user,
        Section? section,
        MGeneralPersonalInfo? master,
        string? snapshotLastName,   // t_orders.user_last_name
        string? snapshotUserName)   // t_orders.user_name
    {
        return new SenderInfo(
            CompanyName:      Coalesce(section?.Company,      master?.CompanyName1),
            FactoryName:      Coalesce(section?.Office,       master?.DepartmentName1),
            DepartmentSub:    master?.DepartmentName2,
            ZipCode:          Coalesce(user?.PostalCode,      master?.ZipCode),
            Address:          Coalesce(user?.Address,         master?.Address1),
            Tel:              Coalesce(user?.PhoneNumber,     master?.Tel),
            Fax:              Coalesce(user?.FaxNumber,       master?.Fax),
            Contact:          Coalesce(user?.LastName,        snapshotLastName, snapshotUserName),
            ReceivingFactory: master?.SimpleName);
    }
}
```

### ISenderInfoResolver / SenderInfoResolver（I/O アダプタ）

```csharp
public interface ISenderInfoResolver
{
    Task<SenderInfo> ResolveAsync(string loginName, string? snapshotLastName, string? snapshotUserName, CancellationToken ct = default);
    Task<string?> ResolveSenderEmailAsync(string loginName, CancellationToken ct = default); // 送信差出人フォールバック用
}
```

- `ResolveAsync`:
  1. `user = await userManager.FindByNameAsync(loginName)`
  2. `section = user != null ? await userRepository.GetMainUserSectionAsync(user.Id)?.Section : null`
  3. `master = await masterService.GetGeneralPersonalInfoAsync(loginName)`（DEFAULT フォールバック込み）
  4. `return SenderInfoMerger.Merge(user, section, master, snapshotLastName, snapshotUserName)`
- `ResolveSenderEmailAsync`:
  - `user?.Email` が非空ならそれ、なければ `master?.Email`（`GetGeneralPersonalInfoAsync`）。両方空なら null。
- 例外は握りつぶさず、`FindByNameAsync`/`GetMainUserSectionAsync` の失敗時は当該ソースを null 扱いにして継続（PDF生成を止めない）。SharedCore 取得で例外が出た場合はログ Warning ＋ null 継続（マスタへフォールバック）。

### OrderPdfService の変更

- コンストラクタに `ISenderInfoResolver` を追加（`MCompanyInfo` 直接取得を置換）。
- `GenerateOrderPdfAsync` / `GenerateGroupOrderPdfAsync` の右上ブロックを `SenderInfo` で構築:
  - 会社名 `sender.CompanyName` / 工場名 `sender.FactoryName` /（非空なら）`sender.DepartmentSub`
  - `〒{sender.ZipCode} {sender.Address}` / `TEL {sender.Tel}　FAX {sender.Fax}`
  - `担当：{sender.Contact}`
  - 明細下部「受入工場」= `sender.ReceivingFactory`
- `snapshotLastName = order.UserLastName`・`snapshotUserName = order.UserName`（グループは代表 `first`）。

### DispatchEnqueueService の変更

- `GetCompanyInfoAsync` 呼び出しを `GetGeneralPersonalInfoAsync` に追随（件名の会社名・fromName は従来どおりマスタ由来を維持。会社名の SharedCore 化は PDF 側に閉じる）。
- 差出人アドレス解決を次順に変更:
  ```
  fromAddress =
      Coalesce(sendConfig?.FromAddress,
               await senderInfoResolver.ResolveSenderEmailAsync(head.UserId, ct),
               _options.FromAddress);
  ```
  - 既存の「未設定ならスキップ」判定は最終フォールバック後の値で行う（従来動作互換）。

## エラー処理

- `FindByNameAsync` が null（退職・改名等）: SharedCore 項目は全て null → マスタ＋担当スナップショットへフォールバック（要件2.8）。PDF 生成は継続。
- 主所属なし（`GetMainUserSectionAsync` が null）: 会社名・工場名のみマスタへフォールバック。
- 補完マスタも該当なし: `GetGeneralPersonalInfoAsync` が DEFAULT 行を返す（要件6.2）。DEFAULT も無ければ各項目 null（空欄印字・例外は投げない）。
- SharedCore アクセス例外: Warning ログ＋当該ソース null 継続。

## 正しさのプロパティ（PBT 対象）

- **Property 1（フィールド単位フォールバック）**: 任意の user/section/master/snapshot について、`Merge` の各項目は「SharedCore 値が非空ならそれ、空ならマスタ、（担当は）さらにスナップショット」に一致する。各項目は独立（他項目の空・非空に影響されない）。
- **Property 2（未解決時の全マスタ化）**: `user == null` かつ `section == null` のとき、郵便/住所/TEL/FAX/会社/工場はマスタ値に一致し、担当は snapshotLastName→snapshotUserName に一致する。
- **Property 3（Coalesce の健全性）**: `Coalesce` は「最初の非空白（trim基準）候補」を返し、全候補が空/NULL なら null を返す（順序保存・空文字/空白は非採用）。
- **Property 4（差出人フォールバック順）**: 差出人解決は `from_address` → 発注者Email → options.FromAddress の順で最初の非空を採用する。

## テスト戦略

- 単体/プロパティ（`MaterialModule.Tests`・xUnit＋FsCheck 2.16.6）:
  - `SenderInfoMergerPropertyTests`（Property 1/2/3）。
  - 差出人解決の順序は静的ヘルパー（`Coalesce`）で Property 4 を検証。
- I/O を伴う `SenderInfoResolver`/`OrderPdfService`/`DispatchEnqueueService` は既存方針どおり結合は最小限（純粋ロジックに寄せて検証）。
- ビルド・実行はユーザー（project-rules）。
