# DB最適化提案（正規化・中間テーブル・BOM準拠）

## 分析結果
- m_items: 656件中7件が重複item_code（同一品目が複数部門に所属するため）
- 品目↔部門: N:N関係（1品目が最大8部門に所属）
- 品目↔倉庫: N:N関係（1品目が最大2倉庫に所属）
- 品目↔仕入先: N:N関係（購買条件テーブル経由で複数仕入先）

## 最適化方針
- 複雑化しない（テーブル数を最小限に）
- BOM準拠（製品→原材料の構成は既存のm_bom_headers/detailsで対応済み）
- 拡張性（将来の生産計画連携に対応）
- 正規化（N:N関係は中間テーブルで解決、重複データを排除）

## 変更内容

### 1. m_items の重複排除
- item_codeをユニークにする（重複7件を統合）
- department_id, warehouse_id をm_itemsから削除（N:N関係のため）
- supplier_id はデフォルト仕入先として残す（1:N、主要仕入先）

### 2. 中間テーブル追加

#### r_item_departments（品目↔部門）
命名規則: r_ + テーブル1 + テーブル2
| カラム | 型 | 説明 |
|---|---|---|
| id | int PK | 主キー |
| item_id | int FK | m_items参照 |
| department_id | int FK | m_departments参照 |
| is_default | bit | デフォルト部門フラグ |
| created_at | datetime | 登録日時 |
| updated_at | datetime | 更新日時 |

#### r_item_warehouses（品目↔倉庫）
| カラム | 型 | 説明 |
|---|---|---|
| id | int PK | 主キー |
| item_id | int FK | m_items参照 |
| warehouse_id | int FK | m_warehouses参照 |
| is_default | bit | デフォルト倉庫フラグ |
| created_at | datetime | 登録日時 |
| updated_at | datetime | 更新日時 |

### 3. m_suppliers の拡充
- m_gen_kobai_jyoken（購買条件）から仕入先データを移行
- 品目↔仕入先はm_items.supplier_id（デフォルト仕入先）で1:Nを維持
  （将来必要なら r_item_suppliers 中間テーブルを追加）

### 4. m_items の変更
- department_id カラムを削除（r_item_departmentsに移行）
- warehouse_id は残す（デフォルト倉庫として使用、r_item_warehousesと併用）
- 重複item_codeを統合（DISTINCT化）
