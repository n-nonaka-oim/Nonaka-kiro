# Design Document

## Overview

本設計は、CommonModule を社内他開発者が各自ソリューションへ**クローン参照して利用**できるようにするための整備（配布・利用・貢献）を定義する。共有モデルは A（現行方式維持＋規約化）＝独立 Git リポジトリを各自クローンし、ホストプロジェクトへ **ProjectReference で取り込み**、Pull/Push で同期する。

本 spec の成果物は**コード機能ではなくリポジトリ整備物（ドキュメント・規約・索引）**である。CommonModule のソース（サービス・画面・エンティティ）は既存のまま変更しない。整備対象は次のとおり。

- ルート `README.md`（利用開始の一次導線）
- `CONTRIBUTING.md`（ブランチ・Pull/Push・PR・破壊的変更の運用）
- `docs/USAGE.md`（消費者向け詳細利用ガイド：参照・ホスト登録・DB・導線）
- `docs/README.md`（既存）への DDL/導線 SQL 索引・適用順の追記
- `CHANGELOG.md`（公開契約の変更告知）

## 現状の資産（把握結果・変更しない前提）

- リポジトリ: 独立 Git リポジトリ。リモート `origin = https://github.com/n-nonaka-oim/CommonModule.git`・既定ブランチ `main`。
- プロジェクト: `CommonModule.csproj`（`Microsoft.NET.Sdk.Razor`・net8.0・`AddRazorSupportForMvc`）。
  - `FrameworkReference: Microsoft.AspNetCore.App`
  - `PackageReference: Microsoft.EntityFrameworkCore (8.0.*)` / `Microsoft.EntityFrameworkCore.SqlServer (8.0.*)`
  - `ProjectReference: ..\clnCoCore\SharedCore\SharedCore.csproj`（相対パス）
  - `InternalsVisibleTo: CommonModule.Tests / DynamicProxyGenAssembly2`
- DI 拡張: `CommonModuleExtensions.AddCommonModule(IServiceCollection, IConfiguration)`。
  - 接続文字列 `CommonDb` 必須（未設定は `InvalidOperationException` で早期検出）。
  - 登録: `CommonDbContext`（SqlServer）／`ISmtpQueueService`／`IPrintQueueService`／`ISendConfigService`（すべて Scoped）。
  - Area `Common` の Razor Pages は Razor Class Library として自動探索（明示登録不要）。
- 画面（Area `Common`）: `/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig`（すべて `[Authorize(Policy="DbPermissionCheck")]`）。
- 対象DB: `db_common_dev`（接続キー `CommonDb`）。
- DDL/データ/移行スクリプト: `docs/sql/`（後述の索引参照）。

## Architecture

### 共有モデル A

```mermaid
flowchart LR
  subgraph Origin[開発元]
    O1[slnCoCore\nCommonModule プロジェクト]
    O2[(GitHub\nn-nonaka-oim/CommonModule)]
    O1 -- push --> O2
  end

  subgraph Consumer[消費者（他開発者）のワークスペース]
    C0[workspace-root]
    C1[clnCoCore\SharedCore\n（消費者が用意＝責務外）]
    C2[clnCommonModule\n（クローン・cln 接頭辞）]
    C3[消費者ホスト（MainWeb 相当）]
    C0 --- C1
    C0 --- C2
    C2 -. 相対参照 ..\clnCoCore\SharedCore .-> C1
    C3 -- ProjectReference --> C2
  end

  O2 -- clone / pull --> C2
  C2 -. PR / push .-> O2
```

要点:
- 消費者は本リポジトリを **`clnCommonModule`（cln 接頭辞）** フォルダにクローンし、**`clnCoCore` の兄弟**に置く（`..\clnCoCore\SharedCore` が解決するため。他モジュール `clnCoCore`/`clnDemoModule` と命名を揃える）。
- SharedCore（`clnCoCore\SharedCore`）は**消費者が用意**する（本 spec 対象外）。
- 消費者ホスト（MainWeb 相当）が `CommonModule.csproj` を ProjectReference し、`AddCommonModule` で登録する。

## フォルダ配置規約（相対パス参照の解決）

`CommonModule.csproj` は `..\clnCoCore\SharedCore\SharedCore.csproj` を参照する。したがって相対パスが壊れない**標準レイアウト**は次のとおり（クローンフォルダは他モジュールと同じ `cln` 接頭辞 `clnCommonModule`）。

```
<workspace-root>\
├── clnCoCore\
│   └── SharedCore\
│       └── SharedCore.csproj      ← 消費者が用意（責務外）
└── clnCommonModule\               ← このリポジトリをクローン（clnCoCore と同階層・cln 接頭辞）
    ├── CommonModule.csproj        →  ..\clnCoCore\SharedCore\SharedCore.csproj
    ├── Areas\Common\Pages\...
    ├── Extensions\CommonModuleExtensions.cs
    └── docs\sql\...
```

規約:
- **必須**: クローンフォルダ `clnCommonModule` は `clnCoCore` と同一の親フォルダ（workspace-root）直下に置く。命名は他モジュール（`clnCoCore`/`clnDemoModule`）と揃え `cln` 接頭辞とする（`CommonModule.csproj` のファイル名は変更しない）。
- 消費者ホストプロジェクトは任意の場所でよいが、`CommonModule.csproj` への ProjectReference は相対/絶対いずれでも可（ホスト→CommonModule のパスは消費者裁量）。
- 推奨と異なる配置にした場合、`..\clnCoCore\SharedCore` が解決できずビルド不能になる旨を README に明記（対処＝標準配置に合わせる）。
- 本 spec では `CommonModule.csproj` の SharedCore 参照は**変更しない**（供給は消費者責務）。

## 利用前提（CoCore ソリューション限定）【2026/07/09 明記】

- **CommonModule は CoCore 系ソリューション内での利用に限定**する。`CommonModule.csproj` がドメイン層 `SharedCore`（`..\clnCoCore\SharedCore\SharedCore.csproj`）を参照するため、SharedCore を供給できる CoCore ソリューション以外では成立しない（単独ビルド不可）。
- 消費者は以下を**自分で**用意/追加する:
  - クローン `clnCommonModule` を**自身の `clnCoCore`（SharedCore を含む）の兄弟**に配置（`..\clnCoCore\SharedCore` が解決する条件）。
  - ホスト（MainWeb 相当）の `.csproj` に `CommonModule.csproj` への `ProjectReference` を追加。
  - `AddCommonModule(configuration)` 登録＋接続文字列 `CommonDb`＋`db_common_dev` のテーブル＋認可導線（`m_content`/`r_content_auth`）。
- ゆえに配置が兄弟でない場合はビルド不可。例: `CoCore\{開発者名}\{clnCoCore, clnCommonModule}` は可／`CoCore\clnCommonModule`（直下・隣に clnCoCore 無し）は SharedCore 未解決で不可。

## レイアウト・命名規約（本体は cln なし／クローンは cln）【2026/07/09 確定】

### 命名規約（このワークスペースの実態に整合）
- **`cln` なし = 開発元の本体作業ツリー**（例: `MaterialModule`・`CommonModule`）。ここで編集し、GitHub へ push する。
- **`cln` あり = クローン**（例: `clnCoCore`・`clnDemoModule`・`clnMaterialModule`・`CoCore\clnCommonModule`）。
- 実態として `clnCoCore\MainWeb` は本体 `..\..\MaterialModule`（cln なし）を参照している。CommonModule もこれに揃える。

### 確定配置（ユーザー確定 2026/07/09）
| 区分 | パス | 役割 |
|---|---|---|
| 本体（開発・push 元） | `…\CoCore\Nonaka\CommonModule` | git 本体（origin=GitHub `n-nonaka-oim/CommonModule`）。slnCoCore が参照 |
| クローン（消費者） | `…\CoCore\clnCommonModule` | 消費者スタイルのクローン（pull のみ・検証用／不要なら退役可） |
| リモート | GitHub `n-nonaka-oim/CommonModule` | 配布の単一真実 |

- 本体 `CommonModule.csproj` 内の `..\clnCoCore\SharedCore\SharedCore.csproj` は `Nonaka` 直下前提で解決（変更不要）。
- 参照4ファイル（`slnCoCore.sln`／`MainWeb.csproj`／`MaterialModule.csproj`／`CommonModule.Tests.csproj`）は本体パス `..\CommonModule\` / `..\..\CommonModule\` を指す（＝元の形）。

### 経緯（2026/07/09・リネームと撤回）
- いったん「単一クローンへ集約」の意図で本体を `Nonaka\clnCommonModule` にリネームし4参照を `clnCommonModule\` に変更したが、**このワークスペースの規約（cln＝クローン）と逆**であったため撤回。本体を `Nonaka\CommonModule` に戻し、4参照も元へ復帰（全走査で旧 cln 参照0件・本体参照4件を確認）。
- 内部 `.git`（origin GitHub）はフォルダ移動の影響を受けない（履歴・リモート追跡は不変・`git repo intact` 確認）。

### 運用ルール（2作業コピーのドリフト防止）
本体 `Nonaka\CommonModule` と消費者クローン `CoCore\clnCommonModule` の2コピーが存在する。**変更は必ず本体でコミット → GitHub へ push、クローンは pull のみ**。push 漏れがドリフトの原因になるため厳守。クローンは検証用途で、不要なら退役してよい。

### 検証
ユーザーが `slnCoCore.sln` をビルドし、全プロジェクトが本体 `..\CommonModule\CommonModule.csproj` を参照して通ることを確認する。

## 成果物（ドキュメント設計）

### 1. ルート `README.md`（一次導線）
構成（見出し）:
1. 概要（CommonModule とは・提供機能の要約・対象読者＝消費者）
2. 共有モデル（クローン＋ProjectReference＝モデル A・SharedCore は消費者責務）
3. クイックスタート（手順の目次：前提 → 配置 → 参照 → ホスト登録 → DB → 導線 → 動作確認）
4. 前提（.NET8／`Microsoft.AspNetCore.App`／EF Core 8／`CommonDb`＝`db_common_dev`／SharedCore 参照が解決可能なこと）
5. 詳細ドキュメントへのリンク（`docs/USAGE.md`・`docs/README.md`（SQL 索引）・`CONTRIBUTING.md`・`CHANGELOG.md`）

### 2. `docs/USAGE.md`（詳細利用ガイド）
- フォルダ配置規約（上記レイアウト図）。
- 参照取り込み: 消費者ホストの `.csproj` に `CommonModule.csproj` を `ProjectReference` 追加する例。
- ホスト登録: `builder.Services.AddCommonModule(builder.Configuration);` と `CommonDb` 接続文字列定義例（値はダミー）。Razor Pages/Area 有効化・`DbPermissionCheck` 前提。
- DB 準備: 必要テーブル一覧＋`docs/sql` の適用順（後述索引）。
- 導線登録: `m_content`/`r_content_auth`（`dbAuthTest`）への登録 SQL と適用手順。
- 動作確認: `/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig` の表示確認。
- トラブルシュート: SharedCore 参照未解決／`CommonDb` 未設定（`InvalidOperationException`）／テーブル未適用時の実行時エラーの症状と対処。

### 3. `docs/README.md` への SQL 索引追記（適用順）
`db_common_dev` 適用順（新規消費者の初期構築）:

| # | スクリプト | 目的 |
|---|---|---|
| 1 | `create_t_smtp_queue.sql` | 送信キュー |
| 2 | `alter_t_smtp_queue_cc_bcc.sql` | CC/BCC・recipient 桁拡張 |
| 3 | `create_m_smtp_config.sql` ＋ `insert_m_smtp_config.sql`（or `update_m_smtp_config_modes.sql`） | 接続プロファイル＋モード行（`mail`/`fax`/`test-fax`） |
| 4 | `create_m_smtp_agent_control.sql` | SmtpAgent 死活 |
| 5 | `create_t_print_queue.sql` | 印刷キュー（pdf_path 必須・output_type/print_payload なし） |
| 6 | `create_m_print_agent_control.sql` | PrintAgent 死活 |
| 7 | `create_m_printer.sql` | プリンタマスタ |
| 8 | `create_m_send_config.sql` ＋ `alter_m_send_config_user_attachment.sql` | 送信設定マスタ（＋owner_user_id/attachment_path） |

導線登録（`dbAuthTest`）: `register_send_config_content.sql` ほか各監視画面の登録 SQL。移行専用（`migrate_t_order_reports_to_t_print_queue.sql`）・テスト専用（`test_smtp_send.sql`）は新規構築では不要である旨を注記。
> 注: `alter_t_print_queue_drop_output_type.sql` は既存DBの是正用。新規は `create_t_print_queue.sql` が最新形のため不要（索引に but-not-for-new を明記）。重複系（`create_smtp_agent.sql`/`create_print_agent_control.sql`）は歴史的スクリプトである旨を注記して現行の正を示す。

### 4. `CONTRIBUTING.md`（貢献・運用）
- ブランチ運用: `main` を保護し、`feature/*` → PR で取り込む。
- 消費者運用: `git pull` で最新取り込み、変更提案は fork/branch → Push → PR。
- モデル A の注意: ProjectReference はソース追従のためバージョン固定がない。`main` の変更は Pull した消費者へ即時影響しうる（安定運用は tag/branch 固定 pull を推奨として記載）。
- 破壊的変更: 公開契約変更時は PR に `breaking` ラベル＋`CHANGELOG.md` 追記を必須とする。

### 5. `CHANGELOG.md`（公開契約の変更告知）
- 公開契約（Public API）を明記し、変更履歴を記録する。
- 公開契約の定義:
  - 投入/読取サービス署名: `ISmtpQueueService.EnqueueAsync(...)`／`IPrintQueueService.EnqueueAsync(...)`／`ISendConfigService.GetActiveAsync/GetForUserAsync(...)`
  - DI 署名: `CommonModuleExtensions.AddCommonModule(IServiceCollection, IConfiguration)`／接続キー `CommonDb`
  - 画面 URL: `/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig`
  - DB スキーマ契約: `docs/sql` の各テーブル定義（列・型）

## 公開契約（消費者が依存する面）

| 種別 | 契約 | 破壊的変更時の扱い |
|---|---|---|
| DI | `AddCommonModule(services, configuration)`／`CommonDb` | CHANGELOG＋移行手順 |
| 投入 | `ISmtpQueueService.EnqueueAsync` の署名 | CHANGELOG＋移行手順 |
| 投入 | `IPrintQueueService.EnqueueAsync` の署名 | CHANGELOG＋移行手順 |
| 読取 | `ISendConfigService.GetActiveAsync/GetForUserAsync` | CHANGELOG＋移行手順 |
| UI | Area `Common` の各ページ URL | CHANGELOG |
| DB | `docs/sql` のテーブル/列定義 | CHANGELOG＋ALTER 提供 |

## 検証（受け入れ確認手順）

コード自動テストの対象ではないため、ドキュメント整備の妥当性は「新規消費者が README/USAGE のみで取り込めること」を手順で確認する（実施はユーザー）。

1. 標準レイアウトに CommonModule をクローン（`clnCoCore\SharedCore` は用意済み前提）。
2. 消費者ホストに `CommonModule.csproj` を ProjectReference 追加 → ビルドが通る。
3. `CommonDb`（`db_common_dev`）を設定し `AddCommonModule` を登録 → 起動する。
4. `docs/sql` の索引順で DDL を適用、導線 SQL を適用。
5. `/Common/SendConfig` 等が権限のあるユーザーで表示できる。
6. README のトラブルシュートで、SharedCore 未解決・`CommonDb` 未設定・テーブル未適用の症状が説明どおり再現/解消できる。

## Non-Goals（本 spec で扱わない）

- SharedCore 等の依存供給（消費者責務）。`CommonModule.csproj` の SharedCore 参照方式の変更もしない。
- Agent 起動/停止の Windows 管理アプリ（別 spec）。
- NuGet（社内フィード）配布・Git submodule 化（将来の発展余地として記録に留める）。
- MainWeb・AuthModule・SharedCore のソース変更。
- CommonModule のコード機能変更（サービス・画面・エンティティの挙動は不変）。

## プロジェクト制約の遵守

- 成果物は CommonModule リポジトリ内（`README.md`・`CONTRIBUTING.md`・`CHANGELOG.md`・`docs/`）に配置し、CommonModule 内で完結する。
- MainWeb・AuthModule・SharedCore は変更しない。
- Spec 正本は `.kiro/specs/CommonModule/commonmodule-distribution/`（単一正本・モジュール別コピーを持たない）。

## Components and Interfaces

本 spec の「コンポーネント」は主にリポジトリ整備物（ドキュメント）と、消費者が依存する既存の公開インターフェースである。

### 整備物コンポーネント（本 spec で作成/更新）
- `README.md`（ルート・一次導線）
- `docs/USAGE.md`（詳細利用ガイド）
- `docs/README.md`（SQL 索引・適用順の追記）
- `CONTRIBUTING.md`（ブランチ・Pull/Push・PR・破壊的変更運用）
- `CHANGELOG.md`（公開契約の変更告知）

各整備物の内容は「成果物（ドキュメント設計）」章に定義する。

### 消費者が依存する既存インターフェース（不変・文書化対象）
- DI: `CommonModuleExtensions.AddCommonModule(IServiceCollection services, IConfiguration configuration)`。接続キー `CommonDb` 必須（未設定時 `InvalidOperationException`）。
- 投入: `ISmtpQueueService.EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body?, cc?, bcc?, pdfPath?, ct?)`。
- 投入: `IPrintQueueService.EnqueueAsync(...)`（pdf_path 必須・印刷専用）。
- 読取: `ISendConfigService.GetActiveAsync(ct?)`／`GetForUserAsync(userId, ct?)`。
- UI: Area `Common` の `/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig`（`DbPermissionCheck`）。

これらの署名・URL は「公開契約」章のとおり CHANGELOG 管理対象とする。本 spec ではコードは変更せず、文書化のみ行う。

## Data Models

本 spec はスキーマを新設・変更しない。消費者が `db_common_dev` に用意すべき既存テーブル群を「契約」として索引化する（詳細は「docs/README.md への SQL 索引追記」章）。

- `t_smtp_queue`（送信キュー・cc/bcc/recipient 拡張含む）
- `m_smtp_config`（接続プロファイル・`mail`/`fax`/`test-fax` モード）
- `m_smtp_agent_control`（SmtpAgent 死活・1行運用）
- `t_print_queue`（印刷キュー・pdf_path 必須・output_type/print_payload なし）
- `m_print_agent_control`（PrintAgent 死活・1行運用）
- `m_printer`（プリンタマスタ・machine×printer 一意）
- `m_send_config`（送信設定マスタ・owner_user_id/attachment_path 含む）

導線（`dbAuthTest`）: `m_content` / `r_content_auth`（各ページの認可・メニュー登録）。

## Correctness Properties

自動テスト対象のコード不変条件ではなく、整備物が満たすべき規約上の不変条件として定義する（検証は手順・レビュー）。

### Property 1: 標準配置ならビルド可能
標準フォルダ配置（`CommonModule` を `clnCoCore` の兄弟に置く）に従えば、`..\clnCoCore\SharedCore` 参照が解決し CommonModule をビルドできる。
**Validates: Requirements 2.3, 3.2, 3.3**

### Property 2: CommonDb 設定で登録成功・未設定で早期検出
`CommonDb` 接続文字列が設定されていれば `AddCommonModule` は例外を出さず登録が完了する。未設定なら `InvalidOperationException` で起動時に早期検出される。
**Validates: Requirements 2.5, 4.1, 4.2**

### Property 3: 索引順適用で列欠落なし
SQL 索引の適用順に従って `db_common_dev` を構築すれば、各画面・投入サービスが参照する列・テーブルがすべて存在し、実行時の列欠落エラーが起きない。
**Validates: Requirements 5.1, 5.2, 5.4**

### Property 4: 破壊的変更は必ず告知される
公開契約（サービス署名・DI 署名・ページ URL・テーブル定義）に変更が入る場合、`CHANGELOG.md` に記録が追加される。
**Validates: Requirements 8.1, 8.2**

## Error Handling

消費者環境で起こりうる代表的な失敗と、README/USAGE のトラブルシュートで示す対処。

- SharedCore 参照が未解決（ビルドエラー）: フォルダ配置規約に合わせる（`clnCoCore\SharedCore` を標準位置に用意＝消費者責務）。
- `CommonDb` 未設定（起動時 `InvalidOperationException: Connection string 'CommonDb' not found.`）: 消費者ホスト設定に `CommonDb` を定義する。
- DDL 未適用（実行時に EF Core が列/テーブル参照で失敗）: SQL 索引の適用順に従って `db_common_dev` を構築する。
- 導線未登録（画面がメニューに出ない/認可で弾かれる）: `m_content`/`r_content_auth` 登録 SQL を `dbAuthTest` に適用する。
- 相対配置のずれ（推奨と異なる場所へクローン）: 標準レイアウトへ再配置する。

## Testing Strategy

コード自動テストは新設しない（整備物のため）。妥当性は「新規消費者が README/USAGE のみで取り込めること」を手順で確認する（実施はユーザー）。手順は「検証（受け入れ確認手順）」章のとおり。
