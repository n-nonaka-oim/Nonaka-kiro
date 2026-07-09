# Implementation Plan: commonmodule-distribution（CommonModule クローン配布の整備）

## Overview

design.md に基づき、CommonModule を他開発者が各自ソリューションへクローン参照して利用できるよう、**リポジトリ整備物（ドキュメント・規約・索引）**を作成する。共有モデルは A（クローン＋ProjectReference・Pull/Push）。CommonModule のソース（サービス・画面・エンティティ・csproj の SharedCore 参照）は**変更しない**。

前提・運用ルール（全タスク共通・厳守）:
- 成果物はすべて **CommonModule リポジトリ内**（ルート `README.md`・`CONTRIBUTING.md`・`CHANGELOG.md`・`docs/`）に作成する。MainWeb・AuthModule・SharedCore は変更しない。
- SharedCore 等の依存供給は消費者責務＝本 spec 対象外。`CommonModule.csproj` の SharedCore 参照方式は変更しない。
- コード追加・スキーマ変更は行わない（文書のみ）。DDL/SQL の実適用・ビルド・動作確認はユーザー（消費者）側。
- Spec 正本は `.kiro/specs/CommonModule/commonmodule-distribution/`（単一正本）。
- CommonModule リポジトリは開発元の作業ツリー `\\...\Nonaka\CommonModule`（独立 Git・origin GitHub）。コミット/Push はユーザー承認のうえ実施。

## Tasks

- [x] 1. ルート README.md を作成（一次導線）（`CommonModule/README.md`・2026/07/09）
  - `CommonModule/README.md` を新規作成
  - 概要（提供機能の要約・対象読者＝消費者）／共有モデル（クローン＋ProjectReference・SharedCore は消費者責務）／クイックスタート目次（前提→配置→参照→ホスト登録→DB→導線→動作確認）／前提（.NET8・`Microsoft.AspNetCore.App`・EF Core 8・`CommonDb`＝`db_common_dev`・SharedCore 参照が解決可能なこと）／詳細ドキュメントへのリンク（USAGE・docs/README・CONTRIBUTING・CHANGELOG）
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.5_

- [x] 2. docs/USAGE.md を作成（詳細利用ガイド）（`CommonModule/docs/USAGE.md`・2026/07/09）
  - [x] 2.1 フォルダ配置規約と参照取り込み手順を記述
    - `CommonModule/docs/USAGE.md` を新規作成し、標準レイアウト図（`CommonModule` を `clnCoCore` の兄弟に置く＝`..\clnCoCore\SharedCore` が解決）を記載
    - 消費者ホスト `.csproj` への `CommonModule.csproj` ProjectReference 追加例／推奨配置と異なる場合に参照が壊れる旨と対処
    - _Requirements: 2.3, 2.4, 3.1, 3.2, 3.3, 3.4_

  - [x] 2.2 ホスト登録・DB 準備・導線登録・動作確認・トラブルシュートを記述
    - `AddCommonModule(configuration)` 呼び出しと `CommonDb`（`db_common_dev`）接続文字列定義例（ダミー値）・Razor Pages/Area 有効化・`DbPermissionCheck` 前提
    - 必要テーブル一覧と `docs/sql` 適用順への参照／`m_content`・`r_content_auth`（`dbAuthTest`）導線登録手順
    - `/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig` 表示確認
    - トラブルシュート（SharedCore 未解決／`CommonDb` 未設定＝`InvalidOperationException`／テーブル未適用の実行時エラー／導線未登録／配置ずれ）
    - _Requirements: 2.5, 4.1, 4.2, 4.3, 4.4, 5.1, 5.3, 5.4, 6.1, 6.3_

- [x] 3. docs/README.md に SQL 索引・適用順を追記（`CommonModule/docs/README.md`・2026/07/09）
  - 既存 `CommonModule/docs/README.md` に、`db_common_dev` 初期構築の適用順表（design「SQL 索引追記」章の8ステップ）と導線登録 SQL（`dbAuthTest`）を追記
  - 新規構築で不要なスクリプト（`alter_t_print_queue_drop_output_type` は既存是正用・`migrate_*` は移行用・`test_smtp_send` はテスト用・重複系 `create_smtp_agent`/`create_print_agent_control` は歴史的）を注記し現行の正を明示
  - _Requirements: 5.1, 5.2, 5.3, 6.2_

- [x] 4. CONTRIBUTING.md を作成（ブランチ・貢献運用）（`CommonModule/CONTRIBUTING.md`・2026/07/09）
  - `CommonModule/CONTRIBUTING.md` を新規作成
  - ブランチ運用（`main` 保護・`feature/*`→PR）／消費者運用（Pull で取り込み・Push/PR で貢献）／モデル A の注意（ソース追従でバージョン固定なし・`main` 変更が即時影響・安定運用は tag/branch 固定 pull 推奨）／破壊的変更 PR には `breaking` ラベル＋CHANGELOG 追記必須
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.3_

- [x] 5. CHANGELOG.md を作成（公開契約と変更告知）（`CommonModule/CHANGELOG.md`・2026/07/09）
  - `CommonModule/CHANGELOG.md` を新規作成
  - 公開契約の定義（`AddCommonModule` 署名・`CommonDb`／`ISmtpQueueService`/`IPrintQueueService`/`ISendConfigService` 署名／Area `Common` ページ URL／`docs/sql` テーブル定義）を明記
  - 破壊的変更時に変更内容と移行手順を記録する運用を記載し、初版（現行状態）のエントリを作成
  - _Requirements: 8.1, 8.2_

- [ ] 6. チェックポイント - 新規消費者手順のドライラン（ユーザー）
  - design「検証（受け入れ確認手順）」に沿って、新規消費者が README/USAGE のみで「クローン→配置→参照→ホスト登録→DB→導線→動作確認」できることをユーザーが確認する
  - SharedCore 未解決／`CommonDb` 未設定／テーブル未適用 の各症状がトラブルシュート記載どおり再現・解消することを確認する
  - _Requirements: 1.1, 3.1, 4.1, 5.1, 6.1_

- [x] 7. レイアウト・命名規約の確定（本体=`CommonModule`／クローン=`clnCommonModule`）（2026/07/09）
  - design「レイアウト・命名規約」章に基づく。規約＝`cln` なし=本体作業ツリー／`cln` あり=クローン（`MaterialModule` と `clnMaterialModule` の先例に整合）。
  - [x] 7.1 本体フォルダ名を `Nonaka\CommonModule` に確定（2026/07/09）
    - 一時的に `clnCommonModule` へリネームしたが規約と逆のため撤回し `CommonModule` に復帰。中身を移動（同一ボリューム・メタデータ操作）＋空フォルダ削除で実施。内部 `.git`／origin 追跡は不変（`git repo intact` 確認）。
  - [x] 7.2 参照4ファイルを本体パス（`..\CommonModule\` / `..\..\CommonModule\`）に確定（2026/07/09）
    - `clnCoCore\slnCoCore.sln`／`clnCoCore\MainWeb\MainWeb.csproj`／`MaterialModule\MaterialModule.csproj`／`clnCoCore\CommonModule.Tests\CommonModule.Tests.csproj`。全走査で旧 cln 参照0件・本体参照4件を確認。
    - `CommonModule\CommonModule.csproj` の SharedCore 参照は変更不要（親 Nonaka のまま解決）。
  - [x] 7.3 チェックポイント（ユーザー）- ビルド確認（2026/07/09・ビルドOK）
    - `slnCoCore.sln` をビルドし、全プロジェクトが本体 `..\CommonModule\CommonModule.csproj` を参照して解決することを確認 → OK
  - [ ] 7.4 チェックポイント（ユーザー）- クローンの位置づけ
    - `CoCore\clnCommonModule` は消費者クローン（pull のみ・検証用）。不要なら退役。運用ルール＝「変更は本体でコミット→GitHub push、クローンは pull のみ」

## Notes

- 本 spec のタスクはすべて**文書作成/追記**であり、コード・スキーマ・csproj は変更しない。
- 成果物は CommonModule リポジトリ（別 Git・origin GitHub）に置く。コミット/Push はユーザー承認のうえ実施し、ブランチ運用（CONTRIBUTING）に従う。
- SharedCore 供給・Windows 管理アプリ・NuGet 配布・submodule 化は対象外（別 spec／将来）。
- チェックポイント 6 の実施（実クローン・実ビルド・実 DB 適用・実表示）はユーザー側。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["2.1", "3", "4", "5"] },
    { "id": 1, "tasks": ["2.2"] },
    { "id": 2, "tasks": ["1"] },
    { "id": 3, "tasks": ["6"] },
    { "id": 4, "tasks": ["7.1"] },
    { "id": 5, "tasks": ["7.2"] },
    { "id": 6, "tasks": ["7.3", "7.4"] }
  ]
}
```
