# Implementation Plan: dispatches-print-default

## Overview

原材料工場入請求画面（`Dispatches/Index`）未登録ビューの印刷チェックボックス（`chkPdfOutput`）の**初期チェック状態のみ**を、ユーザーごとの「印刷既定（ON/OFF）」に従わせる。設定値は既存マスタ `m_user_order_setting` に列 `dispatch_print_default`（bit・既定1=ON）を追加して保持し、設定 UI は `PrintSettings/Index` に相乗りさせる。

実装は最小の検証可能な単位で 1 つずつ進める。編集は `str_replace` / `fs_write` のみ、clnCoCore（MainWeb / AuthModule / SharedCore）は非改変、ビルド・SQL 実行は行わない（ユーザー側で実施）。言語は既存コードベースに合わせて C#。

## Tasks

- [ ] 1. エンティティに印刷既定列を追加
  - [ ] 1.1 `MUserOrderSetting` に `DispatchPrintDefault` 列を追加
    - `Data/Entities/MUserOrderSetting.cs` に `[Required]` + `[Column("dispatch_print_default")]` の `bool DispatchPrintDefault { get; set; } = true;` を追加（既存列・属性は不変）
    - XML ドキュメントコメントで用途（Dispatches 印刷チェックボックス初期状態のみ・既定 ON）を日本語で記述
    - _Requirements: 2.1, 2.2, 2.3_

- [ ] 2. スキーマ変更 SQL（冪等 ALTER）
  - [ ] 2.1 冪等 ALTER SQL を作成
    - `MaterialModule/docs/sql/material/alter_m_user_order_setting_add_dispatch_print_default.sql` を新規作成
    - `COL_LENGTH` による列存在チェック、`BIT NOT NULL` + `DEFAULT(1)`、既存 `create_m_user_order_setting.sql` のヘッダ規約（USE なし・論理ロール material・冪等）に準拠
    - 既存 `default_output_type` は非改変
    - _Requirements: 5.2, 2.1_

- [ ] 3. 純粋ヘルパ `PrintDefaultHelper`
  - [ ] 3.1 `PrintDefaultHelper.Normalize(bool?)` を実装
    - `Services/PrintDefaultHelper.cs` を新規作成（`OutputTypeHelper` と同型の static 純粋ヘルパ）
    - `const bool Fallback = true;` と `Normalize(bool? value) => value ?? Fallback;` を実装
    - _Requirements: 1.4, 3.3_

  - [ ]* 3.2 `PrintDefaultHelper` のプロパティテスト
    - **Property 1: 印刷既定のフォールバック解決** — 非 null 入力はその値、null は常に ON(true)
    - FsCheck.Xunit・最低100反復、`MaterialModule.Tests` に `PrintDefaultHelperPropertyTests`
    - テストタグ: `Feature: dispatches-print-default, Property 1`
    - **Validates: Requirements 1.4, 3.3**

- [ ] 4. サービス拡張（取得・統合保存）
  - [ ] 4.1 `IUserOrderSettingService` にメソッド追加
    - `GetDispatchPrintDefaultAsync(string userCode) => Task<bool?>`（生値・行なしは null）と `SaveOrderSettingAsync(string userCode, int outputType, bool dispatchPrintDefault)` をインターフェースに追加
    - 既存 `GetDefaultOutputTypeAsync` / `SaveDefaultOutputTypeAsync` はシグネチャ・挙動とも不変
    - _Requirements: 2.3, 2.4_

  - [ ] 4.2 `UserOrderSettingService` に実装追加
    - `GetDispatchPrintDefaultAsync`: `AsNoTracking()` で 1 行取得し `DispatchPrintDefault` を返す（null 可）
    - `SaveOrderSettingAsync`: `OutputTypeHelper.IsValid` 検証 → 1 行へ両列を同一 `SaveChangesAsync` でアップサート（未存在は作成／存在は更新）、`row_version` 流用、`DbUpdateConcurrencyException` は呼び出し側へ伝播
    - 既存 `SaveDefaultOutputTypeAsync` のアップサート作法を踏襲、既存メソッドは温存
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.4_

  - [ ]* 4.3 サービスのユニットテスト
    - `SaveOrderSettingAsync`: 未存在→作成（両列）、存在→更新、既定出力区分の非改変（true/false・0/1/2/3）を InMemoryDB で検証
    - `GetDispatchPrintDefaultAsync`: 行あり（true/false）→生値、行なし→null
    - 出力区分値域不正で `ArgumentOutOfRangeException`、既存 `SaveDefaultOutputTypeAsync`/`GetDefaultOutputTypeAsync` の回帰
    - _Requirements: 2.1, 2.3, 3.4_

- [ ] 5. Checkpoint - サービス層まで
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. PrintSettings/Index（設定 UI・保存統合）
  - [ ] 6.1 code-behind に BindProperty と解決・保存統合を追加
    - `[BindProperty] public bool DispatchPrintDefault { get; set; }` を追加
    - `OnGetAsync` / `ReloadAsync` / `OnPostAsync` 末尾で `DispatchPrintDefault = PrintDefaultHelper.Normalize(await orderSettingService.GetDispatchPrintDefaultAsync(userCode));` を実行
    - `OnPostSaveOrderSettingAsync`: 既存の出力区分値域検証を維持し、保存を `SaveOrderSettingAsync(userCode, DefaultOutputType, DispatchPrintDefault)` に差し替え。競合・値域不正メッセージは既存流用
    - _Requirements: 3.2, 3.3, 3.4, 3.5_

  - [ ] 6.2 cshtml にチェックボックスを追加
    - `asp-page-handler="SaveOrderSetting"` フォーム内、既定出力区分 select の近くへ `asp-for="DispatchPrintDefault"` の `form-check` チェックボックス（`id="chkDispatchPrintDefault"`・ラベル「原材料工場入請求 印刷 既定（ON/OFF）」）を追加
    - _Requirements: 3.1_

- [ ] 7. Dispatches/Index（初期チェック状態の反映）
  - [ ] 7.1 code-behind に注入と解決を追加
    - コンストラクタに `IUserOrderSettingService orderSettingService` を注入、公開プロパティ `public bool DispatchPrintDefault { get; set; } = true;` を追加
    - `OnGetAsync` 内で `userCode` を解決し `DispatchPrintDefault = PrintDefaultHelper.Normalize(await orderSettingService.GetDispatchPrintDefaultAsync(userCode));`（POST 経路は不変・GET のみ）
    - _Requirements: 1.1, 1.4_

  - [ ] 7.2 cshtml の `chkPdfOutput` 初期 checked を条件化
    - ハードコード `checked` を `@(Model.DispatchPrintDefault ? "checked" : null)` に変更（**この一箇所のみ**）
    - 要素 id `chkPdfOutput`・送信名 `PdfOutput`・JS 読み取り/分岐・PDF 出力分岐は不変
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.3, 4.4_

- [ ] 8. DB 文書更新
  - [ ] 8.1 テーブル定義書・ER図を更新
    - `.kiro/docs/db/テーブル定義書.md` の `m_user_order_setting` に `dispatch_print_default`（日本語名「原材料工場入請求 印刷既定」/ bit / 備考「既定1=ON、未設定時 ON フォールバック」）を追加
    - `.kiro/docs/db/ER図.md`（存在すれば `ER図.mmd` も）へ当該列を追記
    - _Requirements: 5.3, 5.4_

- [ ] 9. Checkpoint - 実装完了・スコープ確認
  - Ensure all tests pass, ask the user if questions arise.
  - `chkPdfOutput` の変更が初期 `checked` 属性のみであること、clnCoCore 無変更を確認
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1_

- [ ] 10. ユーザーチェックポイント（ビルド・SQL 適用・実機確認）
  - ユーザー側でビルド、`alter_m_user_order_setting_add_dispatch_print_default.sql` の適用、PrintSettings での保存と Dispatches 初期表示の実機確認を実施
  - _Requirements: 5.1, 5.2_

## Notes

- `*` 付きサブタスクは任意（テスト）。MVP では省略可、コア実装は必須。
- 各タスクは要件条項を参照（トレーサビリティ）。
- Property 1 は `PrintDefaultHelper.Normalize` の普遍則を検証（純粋・低コスト）。
- 編集は `str_replace` / `fs_write` のみ。clnCoCore 非改変。ビルド・SQL 実行はユーザー側。
- タスク 10 はコード外作業のためエージェント実装対象外（ユーザー実施項目）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1", "8.1"] },
    { "id": 1, "tasks": ["3.2", "4.1"] },
    { "id": 2, "tasks": ["4.2"] },
    { "id": 3, "tasks": ["4.3", "6.1", "7.1"] },
    { "id": 4, "tasks": ["6.2", "7.2"] }
  ]
}
```
