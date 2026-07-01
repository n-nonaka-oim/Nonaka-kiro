# Requirements Document

## Introduction

本 spec は **共通プリント基盤（Common Print Platform）** を定義する。SMTP送信基盤（SmtpAgent ＋ `t_smtp_queue` ＋ Common_SmtpMonitor）と対になる位置づけで、印刷ジョブの **共通キュー（`t_print_queue`）・ワーカー処理（PrintAgent）・監視WEB（Common_PrintMonitor）** を所有する、他モジュールから独立した共通プラットフォームである。

本 spec は次の範囲を **契約の発生元** として所有する。

1. **`t_print_queue`（db_common_dev の新テーブル）のスキーマ／契約**。`t_smtp_queue` と対の命名・思想で、印刷関連列のみを持つ（FAX列は持たない）。`row_version`（`[Timestamp]`）で楽観ロックを行う。
2. **PrintAgent（ワーカー）の読取先を `t_print_queue`（db_common_dev）へ変更**する要件。PrintAgent は別ソリューション・別 git リポジトリ・独自 Doc 体系で管理されるが、読取先変更は本 spec のスコープに含む。
3. **Common_PrintMonitor（監視WEB）** を CommonModule の Area "Common"（`/Common/PrintMonitor`）に設置し、`t_print_queue` を CommonDbContext 経由で参照する要件。
4. **カットオーバー（移行手順・切替順序）**。投入先（PrintJobService、別 spec）と読取先（PrintAgent、本 spec）の同時切替と、未処理印刷ジョブを取り残さない移行手順を要件化する。

本 spec は **要件定義のみ** を対象とし、実装・コード変更は含まない。

### 他 spec との関係（依存）

- 印刷ジョブの **投入元** である PrintJobService（MaterialModule）の投入先を `t_print_queue` へ変更する実装は、別 spec `dispatch-monitoring-consolidation` が所有する。本 spec は「PrintJobService が `t_print_queue` に投入する」ことを **前提・インターフェース契約** として定義し、投入側の実装は `dispatch-monitoring-consolidation` に委ねる。
- 本 spec（共通プリント基盤）は `t_print_queue` スキーマとカットオーバーの **契約の発生元** である。`dispatch-monitoring-consolidation` は本 spec の契約に依存する。

### スコープ外（Non-Goals）

- PrintJobService（MaterialModule）の投入側実装の改修（本 spec はインターフェース契約のみ定義し、実装は `dispatch-monitoring-consolidation` が所有）。
- MainWeb・AuthModule のソース・設定変更（参照のみ。プラットフォーム登録は CommonModule 側の所有とし、MainWeb への変更は最小限かつ別途ユーザー確認）。
- FAX送信経路（`t_smtp_queue`）および Common_SmtpMonitor の改修（参照・整合確認のみ）。
- 帳票レイアウト・PDF生成ロジックの変更。
- DDL の実適用、既存 `t_order_reports` 印刷データの実移行、ビルド・テスト・実印刷（いずれもユーザー側で実施）。

## Glossary

- **Common_Print_Platform**: 本 spec が定義する共通プリント基盤。`t_print_queue`・PrintAgent・Common_PrintMonitor・カットオーバーを所有する。
- **t_print_queue**: db_common_dev に新設する共通テーブル。印刷ジョブのキュー。`t_smtp_queue` と対の命名・思想で、印刷関連列のみを持ち FAX関連列を持たない。本 spec がスキーマ契約を所有する。
- **t_smtp_queue**: db_common_dev に存在する共通テーブル。FAX/メール送信ジョブのキュー。本 spec では命名・思想の対比対象として参照する。
- **t_order_reports**: db_material_dev に存在する資材固有テーブル。従来は印刷ジョブの正本キューとして `print_status`・`print_payload` 等を保持していた。`t_print_queue` の列設計の参考元であり、本 spec ではこのテーブルへの依存を排除する。
- **PrintJobService**: `MaterialModule/Services/PrintJobService.cs`。承認済み発注を発注番号グループ単位で束ね、印刷ジョブ（PrintPayload付き）を生成する資材モジュールのサービス。本 spec では `t_print_queue` への投入元（Producer）として契約上のみ参照する（投入側実装は `dispatch-monitoring-consolidation` の所有）。
- **PrintAgent**: 印刷ジョブを処理する Worker Service（別ソリューション・別 git リポジトリ: `\\OJIADM23120073\Labs\WindowsService\PrintAgent`、独自 Doc 体系）。`t_print_queue` をポーリングし PDF生成→サイレント印刷を行い、PrintStatus を遷移させる。
- **Common_PrintMonitor**: `CommonModule/Areas/Common/Pages/PrintMonitor`（`/Common/PrintMonitor`）。`t_print_queue` を CommonDbContext 経由で参照する印刷監視画面。
- **Common_SmtpMonitor**: `CommonModule/Areas/Common/Pages/SmtpMonitor`（`/Common/SmtpMonitor`）。`t_smtp_queue` ベースのSMTP監視画面。Common_PrintMonitor の機能・スタイルの参照基準。
- **m_print_agent_control**: db_common_dev に新設する PrintAgent 死活監視テーブル（1行運用）。PrintAgent がポーリング毎に `last_heartbeat_at`（UTC）・`machine_name` を更新する。`m_smtp_agent_control` と対の命名・思想。
- **CommonDbContext**: db_common_dev に接続する CommonModule の DbContext。
- **PrintStatus**: 印刷状態。0=対象外, 1=待機, 2=処理中, 3=完了, 9=エラー。
- **PrintPayload**: 印刷用 JSON。PrintAgent が PDF を再生成して印刷するための入力データ。
- **DbPermissionCheck**: DB権限ベースの認可ポリシー（`[Authorize(Policy = "DbPermissionCheck")]`）。
- **RowVersion**: 楽観的ロック用の行バージョン列（`[Timestamp]` 属性に対応する `row_version` カラム）。
- **カットオーバー**: 印刷ジョブの正本キューを `t_order_reports`（db_material_dev）から `t_print_queue`（db_common_dev）へ切り替える移行作業。投入先（PrintJobService）と読取先（PrintAgent）の切替を含む。

## 前提（Assumptions）

- A1: `t_print_queue` の DDL 適用、`m_print_agent_control` の DDL 適用、および既存 `t_order_reports` 印刷データの `t_print_queue` への移行は、ユーザーが db_common_dev に対して実施する。
- A2: PrintAgent は別ソリューション（`\\OJIADM23120073\Labs\WindowsService\PrintAgent`）・別 git リポジトリ・独自 Doc 体系（requirements/design/tasks）で管理される。本 spec は読取先変更を要件として定義するが、ビルド・デプロイ単位が CommonModule/MainWeb とは別である。
- A3: PrintJobService の `t_print_queue` への投入側実装は別 spec `dispatch-monitoring-consolidation` が所有する。本 spec は投入契約（投入先・PrintStatus 初期値・PrintPayload 付与）のみ定義する。
- A4: FAX送信は `t_smtp_queue`（SMTP送信基盤）に一本化済みであり、`t_print_queue` は FAX を扱わない。
- A5: CommonModule のホスト登録（ModuleRegistration）は CommonModule 側プラットフォームの所有とする。MainWeb への変更が必要な場合は最小限とし、別途ユーザー確認を要する。
- A6: ビルド・テスト・DDL適用・実印刷はユーザー側で実施する。

## Requirements

### Requirement 1: 印刷ジョブ共通キュー `t_print_queue` のスキーマ契約

**User Story:** アーキテクトとして、印刷ジョブを db_common_dev の共通キュー `t_print_queue` で一元管理したい。そうすれば印刷監視と処理を共通基盤上で完結でき、`t_smtp_queue` と並ぶ共通キュー基盤に統一できる。

#### Acceptance Criteria

1. THE Common_Print_Platform SHALL 印刷ジョブを db_common_dev の `t_print_queue` テーブルに保持する。
2. THE t_print_queue SHALL 現 `t_order_reports` の印刷関連列を踏襲した列（report_type, reference_code, output_type, print_status, print_payload, copies, picked_at, printed_at, error_message, created_at, updated_at, row_version）を保持する。
3. THE t_print_queue SHALL FAX関連列（fax_status 等）を保持しない。
4. THE t_print_queue SHALL print_status 列を保持し、当該列の値を 0（対象外）, 1（待機）, 2（処理中）, 3（完了）, 9（エラー）のいずれかとして定義する。
5. THE t_print_queue SHALL print_payload 列を JSON 文字列として保持する。
6. THE t_print_queue SHALL printed_at 列を印刷完了日時として保持する。
7. THE t_print_queue SHALL 命名および設計思想を `t_smtp_queue` と対になる形で定義する。

### Requirement 2: `t_print_queue` の楽観的ロック

**User Story:** 開発保守担当者として、`t_print_queue` の更新が楽観的ロックで保護されてほしい。そうすれば多人数同時操作時のデータ競合を検出できる。

#### Acceptance Criteria

1. THE t_print_queue SHALL 楽観的ロック用の `row_version` 列（`[Timestamp]` 属性に対応する rowversion 型）を保持する。
2. WHEN Common_Print_Platform が `t_print_queue` のレコードを更新する、THE Common_Print_Platform SHALL `row_version` による楽観的ロックで競合を検出する。
3. IF `t_print_queue` レコード更新時に `row_version` の競合（`DbUpdateConcurrencyException`）が発生する、THEN THE Common_Print_Platform SHALL 「他のユーザーが先に更新しました。画面を再読み込みしてください。」を通知する。

### Requirement 3: `t_print_queue` の DDL 適用とデータ移行の責務

**User Story:** 運用管理者として、`t_print_queue` のスキーマ適用と既存データ移行の責務分担を明確にしたい。そうすれば移行作業の主体と範囲が曖昧にならない。

#### Acceptance Criteria

1. THE t_print_queue の DDL 適用 SHALL ユーザーが db_common_dev に対して実施する。
2. THE 既存 `t_order_reports` 印刷データの `t_print_queue` への移行 SHALL ユーザーが db_common_dev に対して実施する。
3. THE 本 spec SHALL `t_print_queue` の列構成・型・制約をユーザーが DDL を作成できる粒度で記録する。

### Requirement 4: 投入元 PrintJobService とのインターフェース契約

**User Story:** アーキテクトとして、印刷ジョブの投入元（PrintJobService）が満たすべき投入契約を本 spec で定義したい。そうすれば投入側実装（別 spec）が契約に沿って実装できる。

#### Acceptance Criteria

1. THE 本 spec SHALL PrintJobService が印刷ジョブを `t_print_queue`（db_common_dev）に投入することを契約として定義する。
2. THE 本 spec SHALL 投入される印刷ジョブが PrintPayload（印刷用 JSON）を保持することを契約として定義する。
3. THE 本 spec SHALL 投入時の print_status 初期値を 1（待機）とすることを契約として定義する。
4. THE 本 spec SHALL PrintJobService の投入側実装の所有を別 spec `dispatch-monitoring-consolidation` に帰属させ、本 spec は投入契約のみを定義する。
5. WHERE PrintJobService（MaterialModule）から共通キュー `t_print_queue` へ投入する手段が必要となる、THE 投入経路の実装形態（CommonModule の投入サービス経由か直接アクセスか）SHALL `dispatch-monitoring-consolidation` の設計フェーズで決定される。

### Requirement 5: PrintAgent の読取先変更

**User Story:** 運用管理者として、PrintAgent が共通キュー `t_print_queue` の印刷ジョブを処理してほしい。そうすれば印刷処理が共通プリント基盤上で動作する。

#### Acceptance Criteria

1. THE PrintAgent SHALL 印刷ジョブの読取先を `t_print_queue`（db_common_dev）とする。
2. THE PrintAgent SHALL `t_order_reports`（db_material_dev）を印刷ジョブの読取先としない。
3. WHEN PrintAgent が `t_print_queue` の待機（print_status=1）ジョブを取得する、THE PrintAgent SHALL 当該ジョブの print_status を 2（処理中）へ更新する。
4. WHEN PrintAgent が印刷を正常に完了する、THE PrintAgent SHALL 当該ジョブの print_status を 3（完了）へ更新し、printed_at に完了日時を設定する。
5. IF PrintAgent が印刷処理に失敗する、THEN THE PrintAgent SHALL 当該ジョブの print_status を 9（エラー）へ更新し、error_message にエラー内容を設定する。
6. WHEN PrintAgent が処理中（print_status=2）のジョブを取得する、THE PrintAgent SHALL PrintPayload から PDF を生成しサイレント印刷を実行する。
7. THE PrintAgent SHALL 資材固有テーブル `t_order_reports` に依存しない。

### Requirement 6: PrintAgent 死活監視

**User Story:** 運用管理者として、PrintAgent の稼働状況を確認したい。そうすれば印刷処理が滞った際に原因を切り分けられる。

#### Acceptance Criteria

1. THE Common_Print_Platform SHALL PrintAgent 死活監視用テーブル `m_print_agent_control`（db_common_dev、1行運用）を定義する。
2. THE m_print_agent_control SHALL 最終応答時刻 `last_heartbeat_at`（UTC）と稼働マシン名 `machine_name` を保持する。
3. WHEN PrintAgent がポーリングを実行する、THE PrintAgent SHALL `m_print_agent_control` の `last_heartbeat_at` と `machine_name` を更新する。
4. THE m_print_agent_control SHALL 命名および設計思想を `m_smtp_agent_control` と対になる形で定義する。

### Requirement 7: PrintAgent のソリューション独立性

**User Story:** 開発保守担当者として、PrintAgent が別ソリューション・別デプロイ単位であることを明示したい。そうすれば改修・デプロイ作業の境界が明確になる。

#### Acceptance Criteria

1. THE 本 spec SHALL PrintAgent が別ソリューション・別 git リポジトリ（`\\OJIADM23120073\Labs\WindowsService\PrintAgent`）・独自 Doc 体系で管理されることを記録する。
2. THE 本 spec SHALL PrintAgent の読取先変更を本 spec のスコープに含めることを記録する。
3. THE 本 spec SHALL PrintAgent のビルド単位およびデプロイ単位が CommonModule・MainWeb とは別であることを記録する。

### Requirement 8: Common_PrintMonitor の設置とデータソース

**User Story:** 運用管理者として、印刷ジョブの状況を CommonModule の共通監視画面で確認したい。そうすれば印刷監視の所在が明確になり、FAX監視と同じ場所で運用できる。

#### Acceptance Criteria

1. THE Common_PrintMonitor SHALL Area "Common"（`/Common/PrintMonitor`）に設置される。
2. THE Common_PrintMonitor SHALL `t_print_queue` を CommonDbContext 経由で参照する。
3. THE Common_PrintMonitor SHALL `t_order_reports`（db_material_dev）を参照しない。
4. THE Common_PrintMonitor SHALL `[Authorize(Policy = "DbPermissionCheck")]` による認可を適用する。

### Requirement 9: Common_PrintMonitor の表示・操作機能

**User Story:** 運用管理者として、Common_PrintMonitor で印刷ジョブの一覧・絞り込み・サマリ・再出力・PrintAgent 死活を確認・操作したい。そうすれば Common_SmtpMonitor と同等の運用が印刷でも可能になる。

#### Acceptance Criteria

1. THE Common_PrintMonitor SHALL 印刷ジョブの一覧（report_type, reference_code, print_status, copies, picked_at, printed_at, error_message, created_at, updated_at）を表示する。
2. THE Common_PrintMonitor SHALL print_status・report_type・キーワード・作成日付範囲によるフィルタ機能を提供する。
3. THE Common_PrintMonitor SHALL print_status 別の件数サマリ（待機・処理中・完了・エラー）を表示する。
4. WHEN 利用者が完了（print_status=3）またはエラー（print_status=9）のジョブを再出力する、THE Common_PrintMonitor SHALL 当該ジョブの print_status を 1（待機）へ戻す。
5. IF 再出力対象のジョブが PrintPayload を保持しない、THEN THE Common_PrintMonitor SHALL 当該ジョブを再出力せず、再出力できない旨を通知する。
6. THE Common_PrintMonitor SHALL `m_print_agent_control` の最終 heartbeat に基づき PrintAgent の死活（ポーリング中／応答なし）を表示する。
7. THE Common_PrintMonitor SHALL 機能範囲（一覧・フィルタ・サマリ・死活表示・再出力）を Common_SmtpMonitor と同等とする。

### Requirement 10: Common_PrintMonitor のスタイル整合

**User Story:** 利用者として、Common_PrintMonitor が Common_SmtpMonitor と一貫したスタイルで表示されてほしい。そうすれば視認性と操作性が保たれる。

#### Acceptance Criteria

1. THE Common_PrintMonitor SHALL CommonModule（Area "Common"）の共通スタイルに準拠する。
2. THE Common_PrintMonitor SHALL Common_SmtpMonitor と一貫した表示スタイルを適用する。

### Requirement 11: カットオーバー（移行手順・切替順序）

**User Story:** 運用管理者として、印刷ジョブの正本キューを `t_order_reports` から `t_print_queue` へ切り替える際に、未処理ジョブを取り残さない手順を定義したい。そうすれば移行時に印刷ジョブの欠落や二重印刷を防げる。

#### Acceptance Criteria

1. THE 本 spec SHALL 投入先（PrintJobService、`dispatch-monitoring-consolidation` 所有）と読取先（PrintAgent、本 spec 所有）を同時に切り替える手順を定義する。
2. THE カットオーバー手順 SHALL 切替時点で `t_order_reports` に残る未処理（print_status=1 または 2）印刷ジョブを `t_print_queue` へ移行する手順を含む。
3. THE カットオーバー手順 SHALL 切替後に `t_order_reports` を印刷ジョブの投入先・読取先として使用しないことを定義する。
4. THE カットオーバー手順 SHALL 切替の順序（DDL適用 → データ移行 → 投入先切替 → 読取先切替）を定義する。
5. IF 切替時点で `t_order_reports` に未処理印刷ジョブが残存する、THEN THE カットオーバー手順 SHALL 当該ジョブを取り残さず `t_print_queue` で処理可能な状態に移行する。

### Requirement 12: モジュール改変原則・Spec配置・基準準拠

**User Story:** 開発保守担当者として、本 spec の作業がプロジェクトルールに準拠してほしい。そうすればモジュール境界とドキュメント整合が保たれる。

#### Acceptance Criteria

1. THE 本spec由来の変更 SHALL MainWeb および AuthModule のソース・設定を変更しない。
2. WHERE CommonModule のホスト登録（ModuleRegistration）変更が必要となる、THE 当該変更 SHALL CommonModule 側プラットフォームの所有とし、MainWeb への変更は最小限とした上で別途ユーザー確認を要する。
3. THE 本spec成果物 SHALL `.kiro/specs/CommonModule/print-platform/` に単一正本として配置される（モジュール別コピーは持たない）。
4. THE 設計・実装 SHALL 基幹システム構築基準（`\\OJIADM23120073\Labs\sdoc\基幹システム構築基準.md`）に準拠する。
5. WHERE 新規エンティティ（`t_print_queue`・`m_print_agent_control`）を追加する、THE 当該エンティティ SHALL プロジェクトの命名規則および排他制御方針に準拠する。

### Requirement 13: dispatch-monitoring-consolidation との責務分界

**User Story:** アーキテクトとして、本 spec と `dispatch-monitoring-consolidation` の責務が重複しないようにしたい。そうすれば契約の所有者が一意になり、設計判断がぶれない。

#### Acceptance Criteria

1. THE 本 spec SHALL `t_print_queue` のスキーマ契約の発生元（所有者）である。
2. THE 本 spec SHALL カットオーバー（移行手順・切替順序）の契約の発生元（所有者）である。
3. THE 本 spec SHALL PrintAgent の読取先変更および Common_PrintMonitor の設置を所有する。
4. THE 本 spec SHALL PrintJobService の投入側実装を所有せず、`dispatch-monitoring-consolidation` に帰属させる。
5. THE 本 spec SHALL FAX一本化・Material_SmtpMonitor 廃止・Common_SmtpMonitor 集約を所有せず、`dispatch-monitoring-consolidation` に帰属させる。
