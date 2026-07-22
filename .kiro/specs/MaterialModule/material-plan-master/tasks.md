# Implementation Plan: 原材料月次計画マスタ（予実管理 Phase 1）

## Overview

原材料の月次計画を品目別に入力・保存し、四半期・半期・年度は月次を集計して表示専用で示す「計画の器＋入力画面」を、既存資産に影響を与えずに MaterialModule 内へ新規追加する。

実装方針（steering・design 準拠）:

- **最小単位・エラー回避を最優先**。1タスク＝1成果物（1ファイル/1機能）。
- **既存に影響しない新規追加から順に積み上げ**、各段階でビルド可能な状態を保つ。
- **ビルドはユーザーが実施**（Kiro からビルドしない）。**DB スキーマ適用もユーザーが実施**。
- `clnCoCore`（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）は不変。変更は MaterialModule 内に閉じる。
- テスト（`MaterialModule.Tests`）は任意（`*` 付き）。DB/UI 副作用のある保存・楽観ロック・集計は代表例／統合テストで担保し、純粋関数 `FiscalPeriodHelper` のみ property-based test の対象とする。

## Tasks

- [x] 1. エンティティ `TMaterialPlan` を新規作成
  - `MaterialModule/Data/Entities/TMaterialPlan.cs` を新規作成
  - design §1 に準拠。`[Table("t_material_plans")]` ＋ `[Column("snake_case", TypeName=...)]` で明示マッピング
  - 列: id / fiscal_year / year_month / item_id / plan_version(nvarchar(40)) / planned_qty / planned_unit_price / planned_amount(いずれも decimal(18,4)) / created_at / updated_at
  - `row_version` は `[Timestamp]`（楽観ロック）。品目ナビゲーション `Item`（`MItem?`・読み取り参照）
  - _Requirements: 2.2, 2.3, 4.4, 5.1_

- [x] 2. `MaterialDbContext` に DbSet と一意インデックスを追記
  - `MaterialModule/Data/MaterialDbContext.cs` に `DbSet<TMaterialPlan> MaterialPlans` を**追記のみ**
  - `OnModelCreating` に一意インデックス `uq_t_material_plans_01 = (FiscalYear, YearMonth, ItemId, PlanVersion)` を追記
  - design §2 準拠。既存の DbSet・インデックス定義は変更しない
  - _Requirements: 4.2, 4.3_

- [x] 3. 冪等スキーマ SQL を新規作成（ユーザーが `db_material_dev` に適用）
  - `MaterialModule/docs/sql/create_t_material_plans.sql` を新規作成
  - design §3 準拠。`IF NOT EXISTS` による冪等 CREATE TABLE ＋ `ROWVERSION` ＋ `SYSUTCDATETIME()` 既定 ＋ 一意インデックス `uq_t_material_plans_01`
  - 物理 FK は付与しない（結果テーブル方針）。適用はユーザー実施
  - _Requirements: 6.3_

- [x] 4. 純粋関数ヘルパ `FiscalPeriodHelper` を新規作成
  - `MaterialModule/Services/FiscalPeriodHelper.cs` を新規作成（static・副作用なし）
  - design §4 準拠。`FiscalQuarter` / `FiscalHalf` enum、`GetFiscalYear` / `GetQuarter` / `GetHalf` / `GetFiscalMonthOrder`、不正月は `ArgumentOutOfRangeException`
  - 会計年度=4月始まり、上期4-9/下期10-3、Q1=4-6/Q2=7-9/Q3=10-12/Q4=1-3
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_

- [-]* 5. `FiscalPeriodHelper` の property-based test を作成（任意・スキップ）
  - `MaterialModule.Tests` に `FiscalPeriodHelperPropertyTests` を作成（最低100反復・境界月 3/4/9/10/12/1・範囲外月をカバー）
  - **Property 1: 会計年度算出の全域整合** — Validates: Requirements 1.1, 1.2
  - **Property 2: 四半期分類の全域写像** — Validates: Requirements 1.3, 1.4, 1.5, 1.6
  - **Property 3: 半期の完全分割** — Validates: Requirements 1.7, 1.8
  - **Property 4: 範囲外の月はエラー** — Validates: Requirements 1.9

- [x] 6. 画面用モデルと PageModel `OnGetAsync` を新規作成
  - 画面用モデル `PlanRow` / `PlanCell` / `PlanSaveRequest` / `PlanSaveCell`（design §5 のレコード定義）
  - `MaterialModule/Areas/Material/Pages/PlanMaster/Index.cshtml.cs` を新規作成。`[Authorize(Policy = "DbPermissionCheck")]`、`MaterialDbContext` ＋ `IMasterService` を Primary Constructor で直接注入
  - `OnGetAsync`: 品目取得（`GetActiveItemsAsync`）＋対象（FiscalYear＋PlanVersion）の既存計画を `AsNoTracking()` で読込＋品目×12ヶ月グリッド構築（列順は `FiscalPeriodHelper.GetFiscalMonthOrder`）＋各行 `row_version`（Base64）返却
  - _Requirements: 2.1, 2.5, 3.4, 3.5, 5.1, 6.1, 6.2_

- [x] 7. 保存ハンドラ `OnPostSaveAsync` を実装（同一ファイルに追記）
  - `Index.cshtml.cs` に `OnPostSaveAsync(PlanSaveRequest req)` を実装（タスク6の後・同一ファイル）
  - 一意キーでアップサート（存在→更新／なし→挿入）、`planned_amount = planned_qty × planned_unit_price`、`fiscal_year` は `FiscalPeriodHelper.GetFiscalYear(year_month)` で決定
  - 新規は `created_at`/`updated_at`、更新は `updated_at` を保存時刻に設定
  - 楽観ロック: 受領 `row_version` を `OriginalValues` に適用。`DbUpdateConcurrencyException` を捕捉し「他のユーザーが先に更新しました。画面を再読み込みしてください。」を返却。成功時は更新後 `row_version` を返却
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.2, 5.3, 5.4_

- [x] 8. ビュー `PlanMaster/Index.cshtml` を新規作成
  - `MaterialModule/Areas/Material/Pages/PlanMaster/Index.cshtml` を新規作成（タスク6の後・別ファイル）
  - 品目×12ヶ月（4月〜翌3月）グリッド。各月セルは数量・単価入力、金額＝数量×単価を vanilla JS で即時再計算表示
  - Q1〜Q4・上期・下期・年度合計を月次値の合計として JS で算出し**表示専用**で表示（会計期割当は `FiscalPeriodHelper` の規則に一致）
  - 数値以外入力は受理せず不正メッセージ表示。版切替（annual / revised_h2）
  - デザイン準拠: 先頭に `<partial name="_MaterialStyles" />`、コンテナ `class="container-fluid mt-3 px-4 material-page" style="font-size: 0.8rem;"`、タイトル `<h5 class="mb-2">@ViewData["Title"]</h5>`、グリッドテーブル `style="font-size: 0.75rem;"`
  - _Requirements: 2.2, 2.3, 2.4, 2.6, 3.1, 3.2, 3.3, 7.1, 7.2, 7.3_

- [x] 9. DB ドキュメントを更新
  - `.kiro/docs/db/テーブル定義書.md` に `t_material_plans` の列一覧（列名・日本語名・型・備考）を追記
  - `.kiro/docs/db/ER図.md` に `t_material_plans` と `m_items` のリレーションを追記
  - _Requirements: 6.3_

- [x] 10. Checkpoint — スコープ・非影響を確認
  - 変更が MaterialModule 内に閉じ、`clnCoCore`（MainWeb / AuthModule / SharedCore / SharedInfrastructure）が不変であることを確認
  - 既存テーブルが不変（新規 `t_material_plans` の追加のみ）、スキーマ適用はユーザー実施であることを確認
  - `m_purchase_conditions` を参照する場合も読み取りのみであることを確認
  - ビルドはユーザーが実施。疑問があればユーザーに確認する
  - _Requirements: 6.3, 6.4, 6.5_

## Notes

- `*` 付きサブタスク（5）は任意。`MaterialModule.Tests` 管理下で FsCheck.Xunit を使用。ビルド・テスト実行はユーザー。
- タスク6・7は同一ファイル `Index.cshtml.cs`（順次・別ウェーブで実行）。タスク8は別ファイル `Index.cshtml`（タスク6の後）。
- 各タスクは要件へトレーサビリティを持つ。DB 適用・ビルドはユーザーが実施。
- 純粋関数のみ property-based test 対象。保存・楽観ロック・集計は UI/DB 副作用に依存するため代表例／統合テストで担保（Testing Strategy 参照）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2"] },
    { "id": 2, "tasks": ["3", "4", "9"] },
    { "id": 3, "tasks": ["5", "6"] },
    { "id": 4, "tasks": ["7", "8"] }
  ]
}
```
