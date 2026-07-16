# Implementation Plan: orders-default-output-type

## Overview

発注エントリ（Orders/Create）モーダルの出力区分の既定値を、ハードコード「3」からユーザーごとの「既定出力区分」に置き換える。純粋ヘルパ `OutputTypeHelper` → 新規エンティティ `MUserOrderSetting` ＋ DbSet ＋ 冪等スキーマSQL → サービス `IUserOrderSettingService` → UI 改修（PrintSettings 設定 / Orders/Create 初期表示）→ 文書整備、の順で最小単位に分割して積み上げる。実装言語は C#（設計で確定済み。言語選択はスキップ）。

全変更は MaterialModule 内で完結し、clnCoCore（MainWeb / AuthModule / SharedCore）は変更しない。ファイル編集は str_replace / fs_write のみ（PowerShell 書き込み禁止）。ビルドはユーザー側で実施する。

## Tasks

- [ ] 1. 出力区分の純粋ヘルパを実装
  - [ ] 1.1 `OutputTypeHelper` を新規作成
    - `MaterialModule/Services/OutputTypeHelper.cs` を作成
    - `const int Fallback = 3` を定義
    - `IsValid(int? value)`：`value is 0 or 1 or 2 or 3` を返す
    - `Normalize(int? value)`：`IsValid` なら生値、それ以外/ null は `Fallback`（3）を返す（戻り値は必ず 0/1/2/3）
    - _Requirements: 1.1, 1.2, 1.3, 2.2, 3.2, 3.3, 3.5_

  - [ ]* 1.2 `OutputTypeHelper` のプロパティテストを作成
    - `MaterialModule.Tests` に `OutputTypeHelperPropertyTests`（FsCheck.Xunit, 最低100反復）を追加
    - **Property 1: 出力区分の正規化（値域・忠実性・フォールバック）**
    - **Validates: Requirements 1.1, 1.2, 1.3, 3.2, 3.3**
    - タグ: `Feature: orders-default-output-type, Property 1`

- [ ] 2. エンティティとDbContextマッピングを追加
  - [ ] 2.1 `MUserOrderSetting` エンティティを新規作成
    - `MaterialModule/Data/Entities/MUserOrderSetting.cs` を作成（`MUserPrintSetting` の規約に厳密準拠）
    - `id`(IDENTITY, PK) / `user_code`(NVARCHAR(40), Required) / `default_output_type`(int, Required) / `created_at` / `updated_at` / `row_version`([Timestamp])
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ] 2.2 `MaterialDbContext` に DbSet と一意インデックスを追加
    - `public DbSet<MUserOrderSetting> UserOrderSettings => Set<MUserOrderSetting>();` をマスタ DbSet 群に追記
    - `OnModelCreating` に `HasIndex(s => s.UserCode).IsUnique().HasDatabaseName("uq_m_user_order_setting_01")` を追記
    - _Requirements: 2.1_

- [ ] 3. 冪等スキーマSQLを作成
  - [ ] 3.1 `create_m_user_order_setting.sql` を新規作成
    - `MaterialModule/docs/sql/create_m_user_order_setting.sql` を作成（`create_m_user_print_setting.sql` の書式に準拠）
    - `USE db_material_dev; GO`、`IF NOT EXISTS` によるテーブル/一意インデックスの冪等作成、`ROWVERSION`、`SYSUTCDATETIME()` 既定
    - CHECK 制約は付与しない（値域はアプリ側検証）
    - _Requirements: 4.2_

- [ ] 4. 既定出力区分サービスを実装
  - [ ] 4.1 `IUserOrderSettingService` インターフェースを作成
    - `MaterialModule/Services/IUserOrderSettingService.cs` を作成（public interface）
    - `Task<int?> GetDefaultOutputTypeAsync(string userCode)` / `Task SaveDefaultOutputTypeAsync(string userCode, int outputType)`
    - _Requirements: 2.1, 3.4_

  - [ ] 4.2 `UserOrderSettingService` 実装を作成
    - `MaterialModule/Services/UserOrderSettingService.cs`（internal, primary constructor で `MaterialDbContext` 注入）
    - `GetDefaultOutputTypeAsync`：`AsNoTracking` で本人行を取得し生値（未設定 null）を返す
    - `SaveDefaultOutputTypeAsync`：`OutputTypeHelper.IsValid` を満たさない値は `ArgumentOutOfRangeException`。未設定は新規作成、既存は差分時のみ更新（`UpdatedAt` 更新）。`DbUpdateConcurrencyException` は呼び出し側へ伝播
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 3.4_

  - [ ] 4.3 DI 登録を追加
    - `MaterialModuleExtensions.AddMaterialModule` に `services.AddScoped<IUserOrderSettingService, UserOrderSettingService>();` を追記
    - _Requirements: 4.1_

  - [ ]* 4.4 保存の往復と単一行性のテストを作成
    - InMemory DB（`Guid.NewGuid()` でDB名一意・`IDisposable` 破棄）で `UserOrderSettingService` を検証
    - **Property 2: 保存の往復と単一行性（有効値）**
    - **Validates: Requirements 2.1, 3.4**
    - タグ: `Feature: orders-default-output-type, Property 2`

  - [ ]* 4.5 不正値拒否（状態不変）のテストを作成
    - {0,1,2,3} 以外の値で保存経路が拒否され、テーブル状態が不変であることを検証
    - **Property 3: 不正値の拒否（状態不変）**
    - **Validates: Requirements 2.2, 3.5**
    - タグ: `Feature: orders-default-output-type, Property 3`

- [ ] 5. Checkpoint - ここまでのテストが通ることを確認
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. PrintSettings/Index に既定出力区分の設定UIを追加
  - [ ] 6.1 `IndexModel` にサービス注入と初期表示解決を追加
    - primary constructor に `IUserOrderSettingService` を追加（既存の印刷設定ロジックは不変）
    - `[BindProperty] public int DefaultOutputType { get; set; }` を追加
    - `OnGetAsync` 末尾で `DefaultOutputType = OutputTypeHelper.Normalize(await orderSettingService.GetDefaultOutputTypeAsync(userCode));`
    - _Requirements: 3.2, 3.3_

  - [ ] 6.2 専用保存ハンドラ `OnPostSaveOrderSettingAsync` を追加
    - 値域検証：`OutputTypeHelper.IsValid` が false なら保存せず不正メッセージを表示（Req 3.5）
    - 正常時：`SaveDefaultOutputTypeAsync` を呼び保存メッセージ（Req 3.4）
    - `DbUpdateConcurrencyException` 捕捉時：「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示（Req 3.6）
    - 既存の印刷設定保存ハンドラとは分離し、既存挙動を変えない
    - _Requirements: 3.4, 3.5, 3.6_

  - [ ] 6.3 `Index.cshtml` に既定出力区分 select を追加
    - 独立フォーム（`asp-page-handler="SaveOrderSetting"`）＋小カードで select（0=出力なし/1=印刷/2=FAX/3=印刷/FAX）を追加
    - `asp-for="DefaultOutputType"` で初期選択を反映。フォント規約（`_MaterialStyles` / 0.75rem 系）を踏襲
    - _Requirements: 3.1, 3.2, 3.3_

- [ ] 7. Orders/Create に既定出力区分の初期表示を反映
  - [ ] 7.1 `CreateModel` にサービス注入と既定解決を追加
    - primary constructor に `IUserOrderSettingService` を追加
    - `public int DefaultOutputType { get; private set; } = OutputTypeHelper.Fallback;` を追加
    - `LoadPageDataAsync` で `DefaultOutputType = OutputTypeHelper.Normalize(await orderSettingService.GetDefaultOutputTypeAsync(userId));`
    - _Requirements: 1.1, 1.2, 1.3_

  - [ ] 7.2 `Order.OutputType` の新規生成箇所に既定を適用
    - `OnGetAsync`：`LoadPageDataAsync` 後に `Order.OutputType ??= DefaultOutputType;`
    - `OnPostAddAsync` / `OnPostEditEntryAsync` の `Order = new OrderCreateDto();` 直後に `Order.OutputType = DefaultOutputType;`
    - バリデーションエラー再表示時はモデルバインド値を保持（Req 1.4）。既存の登録・保存挙動は不変（Req 1.5）
    - _Requirements: 1.1, 1.4, 1.5_

  - [ ] 7.3 `Create.cshtml` モーダル select を `asp-for` 駆動＋JSリセットに変更
    - モーダルの select を `asp-for="Order.OutputType"` 化し、ハードコード `selected` を除去。`id="outputTypeSelect" data-default-output="@Model.DefaultOutputType"` を付与
    - `resetEntryForm()` に「開くたびに既定へ戻す」処理を追記（`outputSel.value = outputSel.dataset.defaultOutput;`）
    - _Requirements: 1.1, 1.2, 1.4_

- [ ] 8. DB文書を更新
  - [ ] 8.1 `テーブル定義書.md` / `ER図.md`（存在すれば `ER図.mmd`）を更新
    - `.kiro/docs/db/テーブル定義書.md` に `m_user_order_setting` の列定義（列名・日本語名・型・備考）を追記
    - `.kiro/docs/db/ER図.md` にリレーションを追記。`ER図.mmd` があれば同様に更新
    - _Requirements: 4.3, 4.4_

- [ ] 9. Final checkpoint - ビルド確認とSQL適用（ユーザー実施）
  - ユーザーにビルド確認を依頼し、`create_m_user_order_setting.sql` を db_material_dev に適用してもらう。疑問があればユーザーに確認する。

## Notes

- `*` 付きサブタスクは任意（PBT/テスト）。スキップ可。実装エージェントは `*` 付きを実装しない。
- 各タスクは要件番号を参照し、トレーサビリティを確保。
- Property 1〜3 は design.md の Correctness Properties に対応（1.2 / 4.4 / 4.5）。
- ファイル編集は str_replace / fs_write のみ。clnCoCore は変更不可。ビルドは Kiro からは実行しない。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1"] },
    { "id": 1, "tasks": ["1.2", "2.2", "4.1", "8.1"] },
    { "id": 2, "tasks": ["4.2"] },
    { "id": 3, "tasks": ["4.3", "4.4", "4.5"] },
    { "id": 4, "tasks": ["6.1", "7.1"] },
    { "id": 5, "tasks": ["6.2", "7.2"] },
    { "id": 6, "tasks": ["6.3", "7.3"] }
  ]
}
```
