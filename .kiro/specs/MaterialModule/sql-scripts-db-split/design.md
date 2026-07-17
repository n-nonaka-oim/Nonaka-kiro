# Design Document

## Overview

MaterialModule の `docs/sql` 配下 24 SQL スクリプトを、論理ロール（material / common / auth）別サブフォルダへ再配置し、各スクリプトの先頭 `USE <db>;`＋直後 `GO` を削除して環境非依存化する。あわせて各スクリプト先頭に「論理ロール＋dev/staging/prod 物理DB名」を明記する DB ヘッダコメントを付与し、`docs/sql/README.md` に対応表・実行手順・実行順/冪等性・auth 非改変方針をまとめる。

本作業は **静的なファイル再配置＋テキスト編集** であり、アプリケーションの実行時挙動やロジックは一切変わらない。SQL・ビルドは実行しない。

### スコープ

- 対象: `MaterialModule/docs/sql` 配下のファイルのみ。
- 非対象: clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）のソース・設定。**一切変更しない**（auth ロールのスクリプトは clnCoCore の Auth DB へデータ登録するものだが、ソースは改変しない）。
- 手段: `smart_relocate`（ファイル移動）＋ `str_replace` / `fs_write`（内容編集・README/ヘッダ作成）のみ。**PowerShell によるファイル書き込みは禁止**。
- AWS 移行全体（RDS 構築・接続文字列切替・Secrets・カットオーバー）は別 spec。

## Architecture

### 移動後のフォルダ構成

```
MaterialModule/docs/sql/
├── README.md                (新規)
├── material/                (19 スクリプト)
├── common/                  (1 スクリプト)
└── auth/                    (4 スクリプト)
```

### 論理ロール → 物理 DB 名 対応表

| 論理ロール | dev | staging | prod |
|---|---|---|---|
| material | db_material_dev | db_material_staging | db_material_prod |
| common | db_common_dev | db_common_staging | db_common_prod |
| auth | dbAuthTest | （環境依存・確定後に追記） | （環境依存・確定後に追記） |

staging / prod の material・common 名は命名規約からの想定値。auth の staging/prod は未定のため README では「環境依存・確定後に追記」と明記する。

### ファイル分類（24 件）

**material/ (19)**: create_m_print_output_path, create_m_print_system_setting, create_m_user_order_setting, create_m_user_print_setting, create_t_order_dispatch_log, create_m_order_statuses, create_m_purchase_types, create_tank_tables, rename_m_company_info_to_general_personal_info, sample_order_approval_10lines, seed_sample_masters, add_item_attributes, add_section_id_to_dispatches, add_usage_columns, purchase_conditions_date_columns_migration, purchase_conditions_dedup_cleanup, set_safety_stock_and_initial_ledger, usage2_3_master_migration, drop_legacy_orphan_tables_db_material_dev

**common/ (1)**: insert_m_calendar

**auth/ (4)**: register_print_monitor_content, register_smtp_monitor_content, unregister_jobqueue_content, unregister_material_monitor_content

## Components and Interfaces

### 処理順序（1 ファイルずつ、最小単位で実施）

順序を固定する。**移動 → 内容編集** の順とし、混在を避ける。

1. **フォルダ作成 + 移動**: 各ファイルを `smart_relocate` で該当ロールのサブフォルダへ移動する（移動先フォルダは自動作成）。`docs` 配下はアプリから参照されないため、import/参照更新の副作用は無い。
2. **内容編集（移動後の各ファイルに対して）**:
   - 先頭に既存コメントブロックがある場合はその直後、無い場合はファイル先頭に **DB ヘッダコメント** を付与する。
   - 先頭付近の `USE <db>;` 行を削除する。
   - その USE 句の直後に単独の `GO` がある場合は併せて削除する。
   - それ以外の DDL / DML 本体は変更しない。
3. **README 作成**: `docs/sql/README.md` を `fs_write` で新規作成する。

> 既存スクリプトは先頭にコメントブロックを持つものがある（例: create_m_user_order_setting.sql）。その場合 DB ヘッダは既存コメントを置換せず、独立した行として明示する。編集は `str_replace` で `USE ...;\nGO` を対象に行い、本体への波及を避ける。

### DB ヘッダコメントの形式

各スクリプト先頭に付与するコメント（論理ロール名＋3環境の物理DB名を明記）:

```sql
-- =============================================================
-- 対象論理ロール: material
-- 物理DB名: dev=db_material_dev / staging=db_material_staging / prod=db_material_prod
-- ※ 実行時は対象DBを選択して適用すること（USE句は環境非依存化のため削除済み）
-- =============================================================
```

common / auth はロール名と対応する物理DB名に置き換える。auth の staging/prod は「未定（環境依存・確定後に追記）」と記す。

### USE / GO 削除パターン

対象は先頭付近の以下の並び（例）:

```sql
USE db_material_dev;
GO
```

`str_replace` で当該2行を除去する。DDL 本体側に現れる `GO`（バッチ区切り）は削除対象外。削除対象はあくまで「先頭 USE 句とその直後の GO」に限定する。

### README 構成

`docs/sql/README.md` には以下を含める（Req 4.1-4.5）:

- 論理ロール → dev/staging/prod 物理DB名 対応表（上表）。
- 実行手順:
  - SSMS: 対象DBをデータベースドロップダウンで選択してから対象フォルダ内スクリプトを実行。
  - sqlcmd: `sqlcmd -S <server> -d <物理DB名> -i <file>`。
- 各ロール内スクリプトの実行順・冪等性の注意（create → alter/migration → seed の順、存在チェック付きで再実行可能なもの／一度きりのものの区別）。
- auth ロールは clnCoCore の Auth DB（dev=dbAuthTest）へのデータ登録であり、**clnCoCore のソースは変更しない**旨。

## Data Models

新規データモデルは無い。SQL ファイル群の配置とヘッダテキストの変更のみ。SQL 内の DDL/DML は不変。

## Error Handling

- 移動先に同名ファイルが既存の場合は移動を中止し、ユーザーへ報告する（上書きしない）。
- `USE` 句が存在しないスクリプトは削除処理をスキップし、ヘッダ付与のみ行う（Req 2.1 は WHERE 条件付き）。
- clnCoCore 配下に差分が生じていないことを各ステップの差分レビューで確認する。混入があれば撤去する。

## Testing Strategy

本作業は静的なファイル再配置＋テキスト編集であり、純粋ロジックや実行時挙動の変化を伴わない。したがって **プロパティベーステスト（PBT）の対象は無い**（「for all inputs X, P(X)」の形で意味のある普遍性質を立てられないため）。自動テスト／SQL 実行／ビルドは行わない。

検証は以下の静的確認（差分レビュー）で行う:

1. **配置確認**: material=19 / common=1 / auth=4、合計24件が過不足なく各サブフォルダに在り、`docs/sql` 直下に SQL が残っていないこと（Req 1.1-1.5）。
2. **USE 消失確認**: 各ファイルに先頭 `USE <db>;` および直後の単独 `GO` が存在しないこと（Req 2.1, 2.2）。
3. **本体不変確認**: 差分がヘッダ付与＋USE/GO削除に限定され、DDL/DML 本体に変更が無いこと（Req 2.3）。
4. **ヘッダ確認**: 各ファイル先頭に論理ロール名と dev/staging/prod 物理DB名を含む DB ヘッダコメントが在ること（Req 3.1-3.3）。
5. **README 確認**: 対応表・実行手順（SSMS / sqlcmd）・実行順/冪等性・auth 非改変方針が記載されていること（Req 4.1-4.5）。
6. **スコープ確認**: 変更ファイルが `MaterialModule/docs/sql` 配下に限定され、clnCoCore に差分が無いこと。過去 session-memo は履歴として非改変であること（Req 5.1-5.4）。

## Correctness Properties

本 spec の全受入基準は静的なファイル配置・テキスト内容の確認（EXAMPLE / SMOKE 分類）であり、入力バリエーションで挙動が変わる純粋ロジックが存在しない。プレワーク分析の結果、PBT に適したユニバーサルプロパティ（「for all inputs」で意味を持つ性質）は抽出されなかった。

したがって Correctness Properties（プロパティベーステスト対象）は **無し**。検証は上記 Testing Strategy の静的確認（差分レビュー）で担保する。
