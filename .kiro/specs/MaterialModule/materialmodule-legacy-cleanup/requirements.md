# Requirements Document

## Introduction

印刷/FAX/送信の各基盤を CommonModule・PrintAgent・SmtpAgent に移行した結果、MaterialModule 内に**移行前の残骸**（空ページ・旧テーブル依存の legacy ページ・未使用エンティティ/DbSet・デッドコード）が残っている。これらを**機能を変えずに安全に撤去**し、コードベースを整理する。

対象は MaterialModule のコード・ページ・EF マッピングと、関連する導線（`m_content`）・DB テーブルの退役。破壊的な DB DROP はユーザー実行、コード側は各段階でビルド可能・可逆に進める。

### 前提・スコープ
- 変更対象は **MaterialModule 内のみ**（＋導線解除 SQL）。MainWeb・AuthModule・SharedCore・CommonModule は変更しない。
- 各タスクは**小規模・単独で検証可能**な単位。1タスク完了ごとにビルド可能な状態を保つ。
- DB テーブルの物理 DROP はユーザー実行（破壊的・要バックアップ）。Kiro はスクリプト作成・コード側撤去まで。
- 保全対象（`t_order_reports`）はコード側の EF マッピングを外しても、テーブル本体は保全期間終了までユーザー判断で残す。

## Glossary

- **空ページ残骸**: `Areas/Material/Pages` 配下でソースファイルが0のディレクトリ（過去に存在した画面の消し残り）。
- **legacy ページ**: 旧パイプライン（`t_order_reports` の PrintStatus/FaxStatus）に依存し、現行（`/Common/PrintMonitor`・`/Common/SmtpMonitor`）に置換済みのページ。
- **未使用エンティティ/DbSet**: 定義と `MaterialDbContext` の DbSet だけが残り、実コードから参照されないエンティティ（CommonModule/db_common_dev へ移行済）。
- **デッドコード**: 撤去済みページ用の DTO/ViewModel／サービスメソッドで、呼び出し元が存在しないもの。
- **導線解除**: `dbAuthTest` の `m_content`/`r_content_auth` から当該ページのメニュー/認可登録を削除すること。

## Requirements

### Requirement 1: 空ページディレクトリの撤去

**User Story:** 開発者として、過去に削除した画面の空ディレクトリを消し、ページ構成を実態に合わせたい。

#### Acceptance Criteria
1. THE 作業 SHALL `Areas/Material/Pages` 配下の空ディレクトリ（`SmtpMonitor`・`PrintMonitor`・`FaxMonitor`・`PrintQueue`・`DeliveryMonitor`・`OrderRecommendation`）を削除する。
2. IF 対象ディレクトリにソースファイルが1つでも存在する場合、THEN THE 作業 SHALL 削除せず内容を提示して確認する。

### Requirement 2: JobQueue ページの廃止

**User Story:** 運用担当者として、印刷/FAX の状況は共通監視画面（/Common/*Monitor）で見るので、旧 JobQueue は不要にしたい。

#### Acceptance Criteria
1. THE 作業 SHALL `Areas/Material/Pages/JobQueue/`（Index.cshtml・Index.cshtml.cs）を削除する。
2. THE 作業 SHALL `m_content`/`r_content_auth`（`dbAuthTest`）から `area='Material'`・`page='JobQueue/Index'` の導線を解除する SQL を作成する（実行はユーザー）。
3. WHERE JobQueue の PDF ダウンロード（`GenerateGroupOrderPdfAsync`）が他ページからも利用されている場合、THE 作業 SHALL 当該サービスは削除せず残す（呼び出し元の有無を確認する）。
4. THE 作業 SHALL JobQueue 削除後もビルドが通る状態を保つ。

### Requirement 3: 未使用エンティティ/DbSet の削除（CommonModule へ移行済）

**User Story:** 開発者として、CommonModule へ移した旧テーブルの EF マッピングを MaterialModule から外し、混乱をなくしたい。

#### Acceptance Criteria
1. THE 作業 SHALL 実コードから参照されないことを確認のうえ、`MSmtpConfig`・`MSmtpAgentControl`・`MPrintAgentControl` のエンティティと `MaterialDbContext` の対応 DbSet を削除する。
2. IF これらを参照するコード（MaterialModule.Tests 含む）が存在する場合、THEN THE 作業 SHALL 削除前にその参照を提示し扱いを確認する。
3. THE 作業 SHALL 削除後もビルドが通る状態を保つ。

### Requirement 4: デッドコードの削除（撤去済みページの残骸）

**User Story:** 開発者として、消したページ用に残った DTO/ViewModel・未使用サービスメソッドを撤去したい。

#### Acceptance Criteria
1. THE 作業 SHALL 呼び出し元が存在しないことを確認のうえ、`DeliveryMonitorDto` と `IOrderService`/`OrderService` の `GetDeliveryMonitorListAsync`（および同系の未使用メソッド）を削除する。
2. THE 作業 SHALL 呼び出し元が存在しないことを確認のうえ、`OrderRecommendationViewModel`（および関連の未使用メソッド）を削除する。
3. IF いずれかに現行の呼び出し元が存在する場合、THEN THE 作業 SHALL 削除せず提示して確認する。
4. THE 作業 SHALL 削除後もビルドが通る状態を保つ。

### Requirement 5: TOrderReport のコード側退役（テーブルは保全）

**User Story:** 開発者として、JobQueue 廃止後に未使用となる `t_order_reports` の EF マッピングを外したい。ただし履歴テーブルは保全したい。

#### Acceptance Criteria
1. WHEN JobQueue 廃止後に `TOrderReport` の参照が定義と DbSet のみになった場合、THE 作業 SHALL `TOrderReport` エンティティと `MaterialDbContext.OrderReports` DbSet を削除する。
2. THE テーブル `t_order_reports` 本体 SHALL 保全期間中は DROP しない（J-2・ユーザー判断）。
3. THE 作業 SHALL 削除後もビルドが通る状態を保つ。

### Requirement 6: DB テーブルの退役（ユーザー実行・破壊的）

**User Story:** DB 管理者として、孤立した旧テーブルを安全に DROP したい。

#### Acceptance Criteria
1. THE 作業 SHALL J-1（db_material_dev の `m_smtp_config`/`m_smtp_agent_control`/`m_print_agent_control`）DROP スクリプトの所在を明示する（既存 `drop_legacy_orphan_tables_db_material_dev.sql`）。実行はユーザー。
2. THE 作業 SHALL `t_order_reports`（J-2）は保全期間終了後にユーザーが DROP する方針を記録する。

### Requirement 7: 保持対象の明示（誤削除防止）

**User Story:** 開発者として、現行機能で使うものは誤って消さないようにしたい。

#### Acceptance Criteria
1. THE 作業 SHALL `MPrintOutputPath`/`PrintOutputPaths`（発注PDFの保存先ベースパス・`PrintOutputPathService` が使用）を**削除しない**。
2. THE 作業 SHALL 現行の業務ページ（Orders/Approvals/Dispatches/Receivings/Delivery/Mrp/OrderPlanning/StockLedger/TankCheck/Forecasts/MasterMaintenance）に影響を与えない。

### Requirement 8: ドキュメント整合

**User Story:** 開発者として、撤去内容を横断資料に反映して実態と一致させたい。

#### Acceptance Criteria
1. THE 作業 SHALL 撤去したエンティティ/テーブルを `.kiro/docs/db/テーブル定義書.md`・`ER図.md` に反映する（該当があれば）。
2. THE 作業 SHALL `.kiro/docs/未実装案件一覧.md` の該当項目（J など）を更新する。
