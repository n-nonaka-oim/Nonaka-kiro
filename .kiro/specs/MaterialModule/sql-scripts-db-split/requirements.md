# Requirements Document

## Introduction

MaterialModule の `docs/sql` 配下に存在する全 SQL スクリプト（24 ファイル）を、対象 DB の論理ロール（material / common / auth）ごとにサブフォルダへ分割し、各スクリプト先頭の `USE <dbname>;` 指定を削除して環境非依存化する。物理 DB 名は環境（dev / staging / prod）で変わるが、論理ロールは不変とする。適用手順・論理ロールと物理 DB 名の対応表・実行順・冪等性の注意を `docs/sql/README.md` にまとめ、将来の環境移行（AWS RDS for SQL Server・SQL 認証を含む）の土台とする。

本 spec のスコープは「SQL スクリプトの再配置・USE 削除・ヘッダ付与・README 整備」に限定する。AWS 移行全体（RDS 構築・接続文字列切替・Secrets・カットオーバー）は別 spec で扱う。

## Glossary

- **SQL_Split_System**: 本 spec が対象とする、`docs/sql` 配下の SQL スクリプト群とその再配置・整備作業の対象範囲を指す論理システム。
- **Logical_Role（論理ロール）**: 対象 DB を環境非依存に識別する不変の役割名。material / common / auth の 3 種。
- **Physical_DB_Name（物理 DB 名）**: 環境ごとに実在する DB 名（例: material→db_material_dev / db_material_staging / db_material_prod、common→db_common_{env}、auth→dev では dbAuthTest）。
- **material ロール**: MaterialModule 業務用 DB（物理: dev=db_material_dev / staging=db_material_staging / prod=db_material_prod）。
- **common ロール**: 共通基盤 DB（物理: db_common_{env}）。
- **auth ロール**: 認証・コンテンツ認可 DB（clnCoCore の Auth DB。dev では dbAuthTest。m_content / r_content_auth 登録系）。
- **USE 句**: SQL スクリプト先頭の `USE <dbname>;` 文（および直後の `GO`）。実行対象 DB を固定的に指定する記述。
- **DB_Header_Comment（DBヘッダコメント）**: 各 SQL 先頭に付与する、対象論理ロールと各環境の物理 DB 名を明記するコメント行。
- **Idempotency（冪等性）**: 同一スクリプトを複数回実行しても結果が変わらない性質。

## Requirements

### Requirement 1: 論理ロール別フォルダへの分割配置

**User Story:** 開発者として、SQL スクリプトを対象 DB の論理ロール別に整理したい。これにより、どのスクリプトをどの DB に適用するかが一目で判別できる。

#### Acceptance Criteria

1. THE SQL_Split_System SHALL `docs/sql` 配下に `material`、`common`、`auth` の 3 サブフォルダを設ける。
2. THE SQL_Split_System SHALL material ロールに属する 19 スクリプト（create_m_print_output_path / create_m_print_system_setting / create_m_user_order_setting / create_m_user_print_setting / create_t_order_dispatch_log / create_m_order_statuses / create_m_purchase_types / create_tank_tables / rename_m_company_info_to_general_personal_info / sample_order_approval_10lines / seed_sample_masters / add_item_attributes / add_section_id_to_dispatches / add_usage_columns / purchase_conditions_date_columns_migration / purchase_conditions_dedup_cleanup / set_safety_stock_and_initial_ledger / usage2_3_master_migration / drop_legacy_orphan_tables_db_material_dev）を `docs/sql/material/` へ配置する。
3. THE SQL_Split_System SHALL common ロールに属する 1 スクリプト（insert_m_calendar）を `docs/sql/common/` へ配置する。
4. THE SQL_Split_System SHALL auth ロールに属する 4 スクリプト（register_print_monitor_content / register_smtp_monitor_content / unregister_jobqueue_content / unregister_material_monitor_content）を `docs/sql/auth/` へ配置する。
5. THE SQL_Split_System SHALL 分割対象を `docs/sql` 配下の 24 スクリプト全件とし、いずれか 1 つの論理ロールフォルダへ過不足なく配置する。

### Requirement 2: USE 句の削除による環境非依存化

**User Story:** 開発者として、各スクリプトから物理 DB 名の固定指定を取り除きたい。これにより、環境ごとに異なる物理 DB 名へ同一スクリプトを適用できる。

#### Acceptance Criteria

1. WHERE スクリプト先頭に USE 句が存在する、THE SQL_Split_System SHALL 当該 USE 句を削除する。
2. WHERE USE 句の直後に単独の `GO` が存在する、THE SQL_Split_System SHALL 当該 `GO` を併せて削除する。
3. THE SQL_Split_System SHALL USE 句以外の DDL および DML 本体を変更せずに保持する。

### Requirement 3: DB ヘッダコメントの付与

**User Story:** 適用担当者として、各スクリプトの対象 DB を明示する記述が欲しい。これにより、USE 句削除後も適用先 DB を誤らずに実行できる。

#### Acceptance Criteria

1. THE SQL_Split_System SHALL 各 SQL スクリプト先頭に DB_Header_Comment を付与する。
2. THE DB_Header_Comment SHALL 当該スクリプトの論理ロール名を明記する。
3. THE DB_Header_Comment SHALL 当該論理ロールに対応する dev / staging / prod の物理 DB 名を明記する。

### Requirement 4: README による対応表と適用手順の整備

**User Story:** 適用担当者として、論理ロールと物理 DB 名の対応、および適用手順を 1 箇所で参照したい。これにより、環境移行時に迷わず正しい DB へ適用できる。

#### Acceptance Criteria

1. THE SQL_Split_System SHALL `docs/sql/README.md` を新規作成する。
2. THE README SHALL 論理ロール（material / common / auth）から各環境（dev / staging / prod）の物理 DB 名への対応表を記載する。
3. THE README SHALL SSMS で対象 DB を選択する手順、および `sqlcmd -d <物理DB名> -i <file>` による実行手順を記載する。
4. THE README SHALL 各ロール内スクリプトの実行順および冪等性に関する注意を記載する。
5. THE README SHALL auth ロールのスクリプトが clnCoCore の Auth DB へのデータ登録であり、clnCoCore のソースを変更しない旨を記載する。

### Requirement 5: スコープ境界の遵守

**User Story:** プロジェクト管理者として、本作業を MaterialModule 内かつドキュメント範囲に限定したい。これにより、他モジュールやアプリケーションコードへの意図しない影響を防げる。

#### Acceptance Criteria

1. THE SQL_Split_System SHALL 変更対象を MaterialModule の `docs/sql` 配下のファイルに限定する。
2. THE SQL_Split_System SHALL clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）のソースおよび設定を変更しない。
3. THE SQL_Split_System SHALL アプリケーションコードから参照されない `docs` 配下のファイルのみを移動対象とする。
4. IF スクリプト移動により過去の session-memo に記載されたパスと差異が生じる、THEN THE SQL_Split_System SHALL 当該 session-memo を履歴として保持し、記載を変更しない。
