# Implementation Plan: send-config-master（送信設定マスタ・管理画面・テスト送信）

## Overview

design.md に基づき、CommonModule（全社共通送信基盤・対象DB `db_common_dev`）の「送信設定マスタ（`m_send_config`）＋読み取りサービス＋管理画面＋投入側へ提供する契約＋テスト送信」を実装する。

本 spec は**実装先行**であり、Unit1〜Unit4（マスタ／サービス／管理画面）は既にコミット済み（CommonModule `f687e13`・`0d54cc5`・`30e9396`／投入側連携 MaterialModule `ab31934`）。本計画は「完了済みの文書化」と「未完了（ドキュメント追記・単発テスト送信ボタン・Mail テスト経路・テスト）」を明確に分けて管理する。

前提・運用ルール（全タスク共通・厳守）:
- **CommonModule 内で完結**（＋導線登録は `dbAuthTest`）。MainWeb・AuthModule・SharedCore は変更しない（参照のみ）。
- 投入の**実処理**（承認画面テスト送信・FAX/Mail enqueue 実装）は別 spec `dispatch-monitoring-consolidation` が所有。本 spec は「送信設定マスタが提供する契約」を所有する。
- 排他制御は `row_version` 楽観的ロック。テストは `CommonModule.Tests`（xUnit + FsCheck 2.16.6・最低100反復・`// Feature: send-config-master` タグ）。
- DDL 適用・導線 SQL 実行・ビルド・テスト実行・実送信は**ユーザー側**。
- Spec は `.kiro/specs/CommonModule/send-config-master/` に単一正本（モジュール別コピーを持たない）。

## Tasks

- [x] 1. 送信設定マスタ `m_send_config`（エンティティ・DbContext・DDL）
  - [x] 1.1 エンティティ `MSendConfig` を実装し `CommonDbContext` に DbSet を追加
    - `CommonModule/Data/Entities/MSendConfig.cs`：`[Table("m_send_config")]`／`[Column]`（snake_case）／`[Key]`＋Identity／`row_version` に `[Timestamp]`。列 = id/from_address/test_fax_number/test_email/is_active/created_at/updated_at/row_version。監査列は created_at/updated_at のみ（created_by/updated_by なし）
    - `CommonModule/Data/CommonDbContext.cs` に `DbSet<MSendConfig>` を追加
    - _Requirements: 1.1, 1.2, 1.3, 1.5_

  - [x] 1.2 DDL＋初期シード SQL を作成
    - `CommonModule/docs/sql/create_m_send_config.sql`（db_common_dev・冪等）：`OBJECT_ID` 未存在時のみ CREATE、有効行なし時のみ初期シード1件。実行はユーザー
    - _Requirements: 1.1, 1.2, 1.6, 1.7_

- [x] 2. DB ドキュメント追記（テーブル定義書・ER図）
  - [x] 2.1 `m_send_config` をテーブル定義書・ER図に追記
    - `.kiro/docs/db/テーブル定義書.md` に `m_send_config`（列名・日本語名・型・備考）を追記（db_common_dev グループ）
    - `.kiro/docs/db/ER図.md` に `m_send_config`（単独マスタ・他テーブルと直接リレーションなし）を追記
    - _Requirements: 1.1_

- [x] 3. 送信設定サービス `ISendConfigService` と DI 登録
  - [x] 3.1 `ISendConfigService` / `SendConfigService` を実装
    - `CommonModule/Services/ISendConfigService.cs`（public・`GetActiveAsync`）＋ `SendConfigService.cs`（internal）
    - 有効行を `AsNoTracking().Where(is_active).OrderBy(Id).FirstOrDefaultAsync`。無ければ `null`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_

  - [x] 3.2 `AddCommonModule` に Scoped 登録を追加
    - `CommonModule/Extensions/CommonModuleExtensions.cs` に `AddScoped<ISendConfigService, SendConfigService>()`
    - _Requirements: 2.5_

  - [ ]* 3.3 有効行選択の決定性のプロパティテスト
    - **Property 1: 有効行選択の決定性**
    - **Validates: Requirements 2.2, 2.3, 2.4**
    - is_active（bool）と id（連番）を持つ行集合を生成し InMemory 投入。`GetActiveAsync` が「is_active=1 の最小 id 行」または（該当なし）`null` を返すことを検証。`// Feature: send-config-master, Property 1` タグ、100反復以上（`CommonModule.Tests`）

- [x] 4. 送信設定管理画面 `/Common/SendConfig`
  - [x] 4.1 PageModel を実装
    - `CommonModule/Areas/Common/Pages/SendConfig/Index.cshtml.cs`：`[Authorize(Policy="DbPermissionCheck")]`・`CommonDbContext` 直接注入
    - 表示：有効行あり→編集フォーム（Id/FromAddress/TestFaxNumber/TestEmail/RowVersion）、無し→空フォーム（新規）
    - 保存：新規＝is_active=1・created_at/updated_at(UTC)、更新＝取得時 row_version を OriginalValue に設定した楽観ロック・updated_at(UTC) 更新
    - 競合＝「他のユーザーが先に更新しました。画面を再読み込みしてください。」／未検出＝「対象の送信設定が見つかりません。画面を再読み込みしてください。」／成功メッセージ（新規/更新）
    - 入力検証：FromAddress `[Required][EmailAddress][MaxLength(256)]`、TestEmail `[EmailAddress][MaxLength(256)]`、TestFaxNumber `[MaxLength(40)]`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

  - [x] 4.2 ビュー `Index.cshtml` を実装
    - Area Common 共通スタイル（Bootstrap5＋vanilla JS、site.css は変更しない）で編集フォーム・検証・メッセージを描画
    - _Requirements: 3.1, 3.3, 3.4_

  - [x] 4.3 導線登録 SQL を作成
    - `CommonModule/docs/sql/register_send_config_content.sql`（dbAuthTest）：`m_content` に Area `Common`・page `SendConfig/Index` を登録（未登録時のみ）＋ `r_content_auth` 権限。実行はユーザー
    - _Requirements: 3.12, 8.3_

  - [ ]* 4.4 管理画面の例示テスト
    - 有効行あり→HasExisting=true・値反映／無し→空フォーム／新規保存→is_active=1・時刻設定・成功／更新→updated_at 更新・成功／未検出メッセージ／ModelState 不正で再表示／競合メッセージ（例外注入 or 並行更新）を `CommonModule.Tests` で検証
    - _Requirements: 3.3, 3.4, 3.7, 3.8, 3.9, 3.10, 3.11_

- [ ] 5. チェックポイント - CommonModule のビルド/テストを通す（ここまでで実装済み分＋2.1 の整合）
  - ビルド／テスト実行はユーザー側。マスタ・サービス・管理画面・DBドキュメントが整合していることを確認する。

- [x] 6. 単発テスト送信（Agent 単体疎通・R6/R7）
  - [x] 6.1 管理画面に「単発テスト送信」ボタンとハンドラを実装
    - `/Common/SendConfig` に FAX／Mail の単発テスト送信ボタンを追加（`_MaterialStyles` 相当の Common スタイル）
    - `OnPostTestSendFaxAsync`：config_key `fax`・宛先 = 有効行 `test_fax_number` の**使い捨てジョブ1件**を `ISmtpQueueService.EnqueueAsync` で enqueue（常駐レコードなし）
    - `OnPostTestSendMailAsync`：config_key `mail`・宛先 = 有効行 `test_email` の使い捨てジョブ1件を enqueue（常駐レコードなし）
    - 対象のテスト宛先（`test_fax_number` / `test_email`）未設定なら enqueue せず、宛先未設定メッセージを表示
    - From は有効行 `from_address`（無ければ既定フォールバック方針に準拠）
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3_

  - [ ]* 6.2 単発テスト送信の例示テスト
    - 宛先設定あり→`EnqueueAsync` が config_key/宛先を正しく1回呼ばれる（FAX=fax+test_fax_number／Mail=mail+test_email）、宛先未設定→enqueue されずメッセージ、を `ISmtpQueueService` モックで検証（`CommonModule.Tests`）
    - _Requirements: 6.2, 6.3, 6.5, 7.1, 7.2_

- [ ] 7. チェックポイント - 単発テスト送信のビルド/テストを通す
  - ビルド／テスト実行はユーザー側。ボタン→enqueue→（SmtpAgent 起動時）実送信の一連が契約どおりであることを確認する。実送信はユーザー側。

## Notes

- `*` 付きサブタスク（テスト）は任意。コア実装タスクには `*` を付けていない。
- タスク1・3・4 は**実装済み（コミット済み）**。タスク2（DBドキュメント追記）・6（単発テスト送信ボタン・R6/R7）・関連テスト（3.3/4.4/6.2）が**未着手の残作業**。
- 投入側の実処理（承認画面「FAXテスト送信」＝R4/R5 の契約実装）は別 spec `dispatch-monitoring-consolidation` が所有する。本 spec は契約定義まで。
- Mail は疎通のみ（config_key=mail＋test_email）。発注書メール等の業務メール送信は対象外。
- DDL 適用（`create_m_send_config.sql`）・導線 SQL（`register_send_config_content.sql`）・ビルド・テスト・実送信はユーザー側。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1"] },
    { "id": 2, "tasks": ["3.2", "4.1"] },
    { "id": 3, "tasks": ["3.3", "4.2", "4.3"] },
    { "id": 4, "tasks": ["4.4", "5"] },
    { "id": 5, "tasks": ["6.1"] },
    { "id": 6, "tasks": ["6.2", "7"] }
  ]
}
```
