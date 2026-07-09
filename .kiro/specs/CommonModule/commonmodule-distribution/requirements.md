# Requirements Document

## Introduction

本 spec は、CommonModule（全社共通基盤モジュール・Area `Common`）を、**社内の他開発者が各自のソリューションにクローン参照して利用できるようにする配布・利用の整備**を対象とする。共有モデルは「現行方式維持＋規約化（モデル A）」を標準とする。すなわち、CommonModule を独立した Git リポジトリ（GitHub `n-nonaka-oim/CommonModule`）として各開発者がクローンし、自分のソリューションへ **ProjectReference で取り込み**、Pull/Push で同期・貢献する方式である。

開発元（CommonModule 保守者）は `slnCoCore` 内に CommonModule プロジェクトを保持するが、他開発者は `slnCoCore` を持たず、クローン経由で CommonModule を各自ソリューションへ参照する。本 spec は、その取り込み・ホスト登録・DB 前提・認可導線・貢献運用を**文書と規約として整備**し、誰が clone しても再現可能に取り込める状態を作ることを目的とする。

新しいコード機能の追加ではなく、**配布容易性・利用手順・貢献運用の整備**が成果物であり、README / CONTRIBUTING / 利用ガイド / DB スクリプト索引などの整備が中心となる。

### スコープ

- 対象: CommonModule リポジトリの配布・利用整備（README・CONTRIBUTING・利用ガイド・DBスクリプト索引・フォルダ配置規約）。**CommonModule のみを対象とする。**
- 共有モデル: A（現行方式維持＋規約化）＝独立 Git リポジトリを各自クローンし、ProjectReference で自ソリューションに取り込み、Pull/Push で同期。submodule 化・NuGet 配布は本 spec の対象外（将来の発展余地として記録のみ）。
- 非対象:
  - SharedCore 等、CommonModule が依存する他基盤の供給・整備（**消費者＝他開発者側の責務**）。
  - Agent 起動/停止の Windows 管理アプリ（別 spec）。
  - MainWeb・AuthModule・SharedCore の変更（参照のみ・不変更）。
  - CommonModule.csproj の SharedCore 参照方式の変更（相対参照のまま。供給は消費者責務）。
- 成果物は CommonModule リポジトリ内（README・CONTRIBUTING・`docs/`）に置き、CommonModule 内で完結させる。

## Glossary

- **CommonModule**: 全社共通基盤モジュール。Razor クラスライブラリ（`Microsoft.NET.Sdk.Razor`・net8.0・Area `Common`）。共通送信基盤（SMTP/FAX）・共通プリント基盤・送信設定マスタ・各監視画面を提供する。対象DB `db_common_dev`。
- **開発元**: CommonModule を保守する主体。`slnCoCore` 内に CommonModule プロジェクトを保持し、リモート `origin`（GitHub `n-nonaka-oim/CommonModule`）へ push する。
- **消費者（他開発者）**: CommonModule を**自分のソリューションで利用する**開発者。`slnCoCore` を持たず、CommonModule リポジトリをクローンして ProjectReference で取り込む。
- **合成ルート（ホスト）**: 消費者ソリューションの Web ホストプロジェクト（開発元の `MainWeb` に相当）。`AddCommonModule` を呼び出し、CommonModule をランタイムでホストする。
- **ProjectReference 取り込み**: 消費者が自ソリューションのホストプロジェクトに `CommonModule.csproj` へのプロジェクト参照を追加して利用する方式（モデル A）。
- **AddCommonModule**: CommonModule の DI 登録拡張メソッド（`CommonModuleExtensions`）。`CommonDbContext`・投入サービス（`ISmtpQueueService`/`IPrintQueueService`）・`ISendConfigService` 等を登録する。
- **CommonDb**: 共通DB（`db_common_dev`）への接続文字列キー。合成ルート側の設定（appsettings 等）に保持し `AddCommonModule(configuration)` 経由で `CommonDbContext` に注入する。
- **導線登録**: 各ページ（`SmtpMonitor`/`PrintMonitor`/`SendConfig`）を認可・メニューに載せるための `m_content` / `r_content_auth`（対象DB `dbAuthTest`）への登録。
- **DbPermissionCheck**: DB 登録内容に基づくページ単位の認可ポリシー（AuthModule が提供）。CommonModule の各ページに適用される。
- **フォルダ配置規約**: 相対パス ProjectReference が解決できるよう、消費者がクローンするフォルダ配置を標準化した取り決め。
- **公開契約（Public API）**: 消費者が依存する CommonModule の公開インターフェース（`ISmtpQueueService`・`IPrintQueueService`・`ISendConfigService` の署名、`AddCommonModule` の署名、Area `Common` のページ URL）。

## Requirements

### Requirement 1: 利用手順（README）の整備

**User Story:** 消費者（他開発者）として、CommonModule をクローンして自分のソリューションで動かすまでの手順を1つの README で把握したい。試行錯誤せずに取り込めるようにするため。

#### Acceptance Criteria

1. THE CommonModule リポジトリ SHALL ルート直下に README を保持し、利用開始に必要な手順を「クローン → 前提確認 → 参照追加 → ホスト登録 → DB 準備 → 導線登録 → 動作確認」の順で記載する。
2. THE README SHALL 対象読者が消費者（他開発者）であることと、共有モデルが「クローン＋ProjectReference（モデル A）」であることを明記する。
3. THE README SHALL 本 spec が CommonModule のみを対象とし、SharedCore 等の依存供給は消費者側の責務であることを明記する。
4. THE README SHALL 参照すべき詳細ドキュメント（利用ガイド・DBスクリプト索引・CONTRIBUTING）へのリンクを含む。

### Requirement 2: 依存・前提の明文化

**User Story:** 消費者として、CommonModule をビルド・実行するために自分のソリューション側で満たすべき前提を明確に知りたい。参照解決やランタイムエラーを避けるため。

#### Acceptance Criteria

1. THE 利用ドキュメント SHALL CommonModule のビルド前提として .NET 8（net8.0）・`Microsoft.AspNetCore.App` FrameworkReference・EF Core 8 系（`Microsoft.EntityFrameworkCore`/`.SqlServer`）を明記する。
2. THE 利用ドキュメント SHALL CommonModule が `SharedCore` へのプロジェクト参照を必要とすることを明記し、SharedCore の供給は消費者側の責務であることを記載する。
3. THE 利用ドキュメント SHALL CommonModule 現行の SharedCore 参照が相対パス（`..\clnCoCore\SharedCore`）であることを明記し、消費者ソリューションで当該参照が解決可能である必要があることを記載する。
4. WHERE SharedCore 参照が消費者環境で解決できない場合、THE 利用ドキュメント SHALL 参照が解決できないと CommonModule がビルドできない旨と、供給は消費者責務（本 spec 対象外）である旨を明記する。
5. THE 利用ドキュメント SHALL 対象DBが `db_common_dev` であり、接続文字列キーが `CommonDb` であることを明記する。

### Requirement 3: 参照取り込み手順とフォルダ配置規約

**User Story:** 消費者として、CommonModule を自分のソリューションへ確実に取り込みたい。相対パス参照が壊れないように標準の配置で取り込むため。

#### Acceptance Criteria

1. THE 利用ドキュメント SHALL 消費者ソリューションのホストプロジェクトに `CommonModule.csproj` を ProjectReference として追加する手順を記載する。
2. THE 利用ドキュメント SHALL クローン先のフォルダ配置規約（相対パス参照が解決できる標準レイアウト）を明示し、推奨配置を図または例で示す。
3. WHERE 消費者が推奨配置と異なる場所にクローンした場合、THE 利用ドキュメント SHALL 相対パス参照が壊れうること、および対処（推奨配置に合わせる）を記載する。
4. THE 参照取り込み手順 SHALL MainWeb・AuthModule・SharedCore を変更しないこと（消費者側ホストへの参照追加のみで完結）を前提とする。

### Requirement 4: ホスト登録（AddCommonModule）の手順

**User Story:** 消費者として、取り込んだ CommonModule を自分のホストで正しく起動したい。DI 登録と接続文字列注入の抜けを防ぐため。

#### Acceptance Criteria

1. THE 利用ドキュメント SHALL 合成ルート（ホスト）で `AddCommonModule(configuration)` を呼び出す手順を記載する。
2. THE 利用ドキュメント SHALL 接続文字列キー `CommonDb`（`db_common_dev`）を消費者ホストの設定に定義し `AddCommonModule` 経由で `CommonDbContext` に注入することを記載する。
3. THE 利用ドキュメント SHALL Area `Common` のページ（`/Common/SmtpMonitor`・`/Common/PrintMonitor`・`/Common/SendConfig`）がランタイムでホストされる前提（ホストが Razor Pages/Area ルーティングを有効にしていること）を記載する。
4. THE 利用ドキュメント SHALL 認可ポリシー `DbPermissionCheck`（AuthModule 提供）が消費者ホストで利用可能である前提を記載する。

### Requirement 5: DB 前提とスクリプト索引

**User Story:** 消費者として、CommonModule が必要とする DB オブジェクトを漏れなく用意したい。実行時の欠落エラーを避けるため。

#### Acceptance Criteria

1. THE 利用ドキュメント SHALL CommonModule が `db_common_dev` に必要とするテーブル一覧（`t_smtp_queue`・`m_smtp_config`・`m_smtp_agent_control`・`t_print_queue`・`m_print_agent_control`・`m_printer`・`m_send_config`）を明記する。
2. THE リポジトリ SHALL `docs/sql`（または相当）配下の DDL・初期データ・ALTER スクリプトの索引を提供し、適用順とともに一覧化する。
3. THE 利用ドキュメント SHALL DDL・SQL の適用は消費者側が `db_common_dev` に対して実施する作業であることを明記する。
4. WHERE 必要テーブルまたは列が未適用の場合、THE 利用ドキュメント SHALL 実行時に EF Core が該当列を参照して失敗しうる旨（適用漏れの症状）を注意として記載する。

### Requirement 6: 認可・導線登録の手順

**User Story:** 消費者として、CommonModule の各画面をメニュー表示・認可対象にしたい。権限のあるユーザーだけがアクセスできるようにするため。

#### Acceptance Criteria

1. THE 利用ドキュメント SHALL 各ページを認可・メニューに載せるための `m_content` / `r_content_auth`（対象DB `dbAuthTest`）への登録が必要であることを記載する。
2. THE リポジトリ SHALL 導線登録用 SQL（例: `register_send_config_content.sql` 等）の索引と適用手順を提供する。
3. THE 利用ドキュメント SHALL 導線登録の適用は消費者側の作業であることを明記する。

### Requirement 7: ブランチ・貢献運用（CONTRIBUTING）の整備

**User Story:** 消費者・開発元として、Pull/Push で安全に同期・貢献したい。破壊やコンフリクトを抑えて共同運用するため。

#### Acceptance Criteria

1. THE リポジトリ SHALL CONTRIBUTING（または README 内の該当節）でブランチ運用（`main` を保護し feature ブランチ→PR で取り込む）を規定する。
2. THE 貢献ドキュメント SHALL 消費者が Pull で最新を取り込み、変更提案を Push/PR で戻す運用を記載する。
3. THE 貢献ドキュメント SHALL モデル A（ProjectReference・ソース追従）ではバージョン固定が無く、`main` の変更が Pull した消費者へ即時に影響しうることを明記する。
4. THE 貢献ドキュメント SHALL 破壊的変更（下記 Requirement 8）の告知手順を参照する。

### Requirement 8: 公開契約の安定性と破壊的変更の告知

**User Story:** 消費者として、依存している公開 API が予告なく壊れないようにしたい。アップグレード時の破損を避けるため。

#### Acceptance Criteria

1. THE 開発元 SHALL 公開契約（`ISmtpQueueService`・`IPrintQueueService`・`ISendConfigService` の署名、`AddCommonModule` の署名、Area `Common` のページ URL）を消費者が依存する公開 API として文書化する。
2. WHEN 公開契約に破壊的変更（署名変更・削除・列/挙動の互換性喪失）を加える場合、THE 開発元 SHALL 変更内容と移行手順を CHANGELOG（または相当の告知）に記載する。
3. THE 貢献ドキュメント SHALL 破壊的変更を伴う PR にはその旨のラベル/注記を付ける運用を記載する。

### Requirement 9: 変更範囲とプロジェクト制約の遵守

**User Story:** プロジェクト保守者として、本整備が定められた変更範囲に収まることを保証したい。共通基盤の一貫性を保つため。

#### Acceptance Criteria

1. THE 本 spec の成果物 SHALL CommonModule リポジトリ内（README・CONTRIBUTING・`docs/`）に配置し、CommonModule 内で完結する。
2. THE 本 spec SHALL MainWeb・AuthModule・SharedCore を変更しない。
3. THE 本 spec SHALL CommonModule.csproj の SharedCore 参照方式を変更しない（供給は消費者責務・対象外）。
4. THE 本 spec SHALL Agent 起動/停止の Windows 管理アプリ・NuGet 配布・submodule 化を対象に含めない（将来の発展余地として記録に留める）。
