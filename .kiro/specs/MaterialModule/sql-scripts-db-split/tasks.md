# Implementation Plan: SQL スクリプト DB ロール別分割

## Overview

`MaterialModule/docs/sql` 配下の 24 SQL スクリプトを論理ロール（material 19 / common 1 / auth 4）別サブフォルダへ再配置し、各スクリプトの先頭 `USE <db>;`（＋直後の単独 `GO`）を削除して環境非依存化する。あわせて各スクリプト先頭に「論理ロール＋dev/staging/prod 物理DB名」を明記する DB ヘッダコメントを付与し、`docs/sql/README.md` に対応表・実行手順・実行順/冪等性・auth 非改変方針をまとめる。

本作業は **静的なファイル再配置＋テキスト編集** に限定する。手段は `smart_relocate`（移動）＋ `str_replace` / `fs_write`（編集・作成）のみ。**PowerShell によるファイル書き込みは禁止**。clnCoCore は一切変更しない。SQL・ビルド・自動テストは実行しない（design の Testing Strategy に従い PBT/テストタスクは無し）。

処理は各ロールごとに「(a) 移動 → (b) 各ファイルの USE/GO 削除＋ヘッダ付与」の順で進める。移動と編集を混在させない。

## Tasks

- [ ] 1. material ロールの再配置と編集
  - [ ] 1.1 material 19 スクリプトを `docs/sql/material/` へ移動
    - `smart_relocate` で以下 19 ファイルを `docs/sql/material/` へ移動（移動先フォルダは自動作成）: create_m_print_output_path, create_m_print_system_setting, create_m_user_order_setting, create_m_user_print_setting, create_t_order_dispatch_log, create_m_order_statuses, create_m_purchase_types, create_tank_tables, rename_m_company_info_to_general_personal_info, sample_order_approval_10lines, seed_sample_masters, add_item_attributes, add_section_id_to_dispatches, add_usage_columns, purchase_conditions_date_columns_migration, purchase_conditions_dedup_cleanup, set_safety_stock_and_initial_ledger, usage2_3_master_migration, drop_legacy_orphan_tables_db_material_dev
    - 移動先に同名ファイルがある場合は上書きせず中止しユーザーへ報告
    - _Requirements: 1.1, 1.2, 1.5, 5.1, 5.3_

  - [ ] 1.2 material create 系 8 ファイルの USE/GO 削除＋DBヘッダ付与
    - 対象: create_m_print_output_path, create_m_print_system_setting, create_m_user_order_setting, create_m_user_print_setting, create_t_order_dispatch_log, create_m_order_statuses, create_m_purchase_types, create_tank_tables
    - 各ファイルの先頭 `USE <db>;` と直後の単独 `GO` を `str_replace` で削除。USE 句が無いファイルは削除をスキップしヘッダ付与のみ
    - 先頭に material ロール用 DB ヘッダコメント（dev=db_material_dev / staging=db_material_staging / prod=db_material_prod）を付与。既存コメントブロックがある場合は置換せず独立行として追加
    - DDL/DML 本体は不変とする
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 5.1_

  - [ ] 1.3 material add/migration/rename 系 8 ファイルの USE/GO 削除＋DBヘッダ付与
    - 対象: rename_m_company_info_to_general_personal_info, add_item_attributes, add_section_id_to_dispatches, add_usage_columns, purchase_conditions_date_columns_migration, purchase_conditions_dedup_cleanup, set_safety_stock_and_initial_ledger, usage2_3_master_migration
    - 各ファイルの先頭 `USE <db>;` と直後の単独 `GO` を削除（無ければスキップ）
    - material ロール用 DB ヘッダコメントを付与
    - 本体側のバッチ区切り `GO` は削除しない
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 5.1_

  - [ ] 1.4 material seed/sample/drop 系 3 ファイルの USE/GO 削除＋DBヘッダ付与
    - 対象: sample_order_approval_10lines, seed_sample_masters, drop_legacy_orphan_tables_db_material_dev
    - 各ファイルの先頭 `USE <db>;` と直後の単独 `GO` を削除（無ければスキップ）
    - material ロール用 DB ヘッダコメントを付与
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 5.1_

- [ ] 2. common ロールの再配置と編集
  - [ ] 2.1 insert_m_calendar を `docs/sql/common/` へ移動
    - `smart_relocate` で insert_m_calendar を `docs/sql/common/` へ移動
    - _Requirements: 1.1, 1.3, 1.5, 5.1, 5.3_

  - [ ] 2.2 insert_m_calendar の USE/GO 削除＋DBヘッダ付与
    - 先頭 `USE <db>;` と直後の単独 `GO` を削除（無ければスキップ）
    - common ロール用 DB ヘッダコメント（dev=db_common_dev / staging=db_common_staging / prod=db_common_prod）を付与
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 5.1_

- [ ] 3. auth ロールの再配置と編集
  - [ ] 3.1 auth 4 スクリプトを `docs/sql/auth/` へ移動
    - `smart_relocate` で以下 4 ファイルを `docs/sql/auth/` へ移動: register_print_monitor_content, register_smtp_monitor_content, unregister_jobqueue_content, unregister_material_monitor_content
    - _Requirements: 1.1, 1.4, 1.5, 5.1, 5.3_

  - [ ] 3.2 auth 4 ファイルの USE/GO 削除＋DBヘッダ付与
    - 各ファイルの先頭 `USE <db>;` と直後の単独 `GO` を削除（無ければスキップ）
    - auth ロール用 DB ヘッダコメント（dev=dbAuthTest / staging=未定（環境依存・確定後に追記） / prod=未定（環境依存・確定後に追記））を付与
    - auth スクリプトは clnCoCore の Auth DB へのデータ登録だが、clnCoCore のソースは変更しない（移動・編集対象は `docs/sql` 配下のファイルのみ）
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 5.1, 5.2_

- [ ] 4. README の作成
  - [ ] 4.1 `docs/sql/README.md` を新規作成
    - `fs_write` で新規作成
    - 論理ロール（material / common / auth）→ dev/staging/prod 物理DB名 対応表を記載（auth の staging/prod は「環境依存・確定後に追記」）
    - SSMS で対象DBを選択する手順、および `sqlcmd -S <server> -d <物理DB名> -i <file>` による実行手順を記載
    - 各ロール内スクリプトの実行順（create → alter/migration → seed）と冪等性の注意（再実行可否）を記載
    - auth ロールが clnCoCore の Auth DB（dev=dbAuthTest）へのデータ登録であり、clnCoCore のソースを変更しない旨を記載
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.2_

- [ ] 5. 確認チェックポイント（差分レビュー）
  - ユーザーによる差分レビューを実施する。ビルド・SQL 実行はしない。以下を静的に確認:
    - 配置: material=19 / common=1 / auth=4（計24件）が過不足なく各サブフォルダに在り、`docs/sql` 直下に SQL が残っていないこと（Req 1.1-1.5）
    - USE 消失: 各ファイルに先頭 `USE <db>;` と直後の単独 `GO` が無いこと（Req 2.1, 2.2）
    - 本体不変: 差分がヘッダ付与＋USE/GO削除に限定され、DDL/DML 本体に変更が無いこと（Req 2.3）
    - ヘッダ: 各ファイル先頭に論理ロール名と dev/staging/prod 物理DB名を含む DB ヘッダコメントが在ること（Req 3.1-3.3）
    - README: 対応表・実行手順・実行順/冪等性・auth 非改変方針が記載されていること（Req 4.1-4.5）
    - スコープ: 変更が `MaterialModule/docs/sql` 配下に限定され、clnCoCore に差分が無く、過去 session-memo が非改変であること（Req 5.1-5.4）
    - 疑問があればユーザーに確認する
  - _Requirements: 1.1, 1.5, 2.1, 2.2, 2.3, 3.1, 4.1, 5.1, 5.2, 5.4_

## Notes

- 本 spec は静的なファイル再配置＋テキスト編集であり、design の Testing Strategy に従い PBT/自動テスト/SQL 実行/ビルドは行わない（テストタスクは無し）。
- 手段は `smart_relocate`（移動）＋ `str_replace` / `fs_write`（編集・作成）のみ。PowerShell によるファイル書き込みは禁止。
- 各ロールは「移動 → 編集」の順で進め、移動と編集を混在させない。
- clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）は一切変更しない。
- 過去 session-memo に記載されたパスは履歴として保持し、記載を変更しない（Req 5.4）。
- 各タスクは特定の要件クローズへトレーサビリティを持つよう `_Requirements:_` を付与している。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "1.4", "2.2", "3.2"] },
    { "id": 2, "tasks": ["4.1"] }
  ]
}
```
