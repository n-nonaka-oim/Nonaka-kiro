# Database Migration: Legacy -> New System

## Source Database
- Server: OJIADM23120073\DEVELOPMENT
- Database: dbNsShizai (legacy material management)
- Database: dbNsASP (legacy web system)

## Migration Summary

| Source Table | Target DB | Target Table | Records | Method |
|---|---|---|---|---|
| dbNsShizai.m_hinmoku | db_material_dev | m_items | 656 | DISTINCT by sap_id |
| dbNsShizai.m_nisugata | db_material_dev | m_package_types | 10 | Direct copy |
| dbNsShizai.m_hinmoku (section_id) | db_factory_dev | m_departments | 18 | DISTINCT |
| dbNsShizai.m_hinmoku (soko_id) | db_factory_dev | m_warehouses | 32+ | DISTINCT |
| dbNsASP.m_soko | db_factory_dev | m_warehouses | 38 | Merged (name, capacity) |
| dbNsShizai.m_sap_shiiresaki | db_factory_dev | m_suppliers | 2236 | Full copy |
| dbNsShizai.m_hannyu_basyo | db_factory_dev | m_delivery_locations | 85 | With dept FK |
| dbNsShizai.m_hinmoku (multi-dept) | db_material_dev | r_item_departments | 1158 | N:N junction |
| dbNsShizai.m_hinmoku (multi-wh) | db_material_dev | r_item_warehouses | 659 | N:N junction |
| dbNsShizai.m_gen_kobai_jyoken | db_material_dev | m_items.supplier_id | 533/656 | FK link via bigint cast |
| dbNsShizai.t_moto | db_material_dev | m_items.default_order_qty | 600+ | AVG(nyuko_suryo/order_unit_qty) ROUND |

## Column Mapping: m_hinmoku -> m_items

| Legacy (m_hinmoku) | New (m_items) | Notes |
|---|---|---|
| sap_id | item_code | |
| sap_name | item_name | |
| simple_name | short_name | |
| irime | content_qty | Cast to decimal |
| unit | content_unit | |
| sap_unit | order_unit_qty | Cast to decimal |
| nisugata_id | package_type_id | Via m_package_types lookup |
| soko_id | warehouse_id | Via m_warehouses lookup |
| section_id | department_id | Via m_departments lookup |
| zaiko_kosu_limit | stock_minimum_qty | |
| nyuko_kosu_unit | receiving_unit_qty | |
| delivery_date | default_delivery_days | |
| bin_input_lot | input_lot | |

## Column Mapping: m_sap_shiiresaki -> m_suppliers

| Legacy | New | Notes |
|---|---|---|
| 会社ｺｰﾄﾞ | company_code | |
| 仕入先ｺｰﾄﾞ | supplier_code | |
| 正式名称 | formal_name | |
| 支店部課名 | branch_name | |
| 略称 | supplier_name | |
| 郵便番号 | zip_code | |
| 住所１ | address | |
| 住所２ | address_2 | |
| 電話番号 | tel | |
| FAX番号 | fax | |

## Column Mapping: m_soko -> m_warehouses

| Legacy (m_soko) | New (m_warehouses) | Notes |
|---|---|---|
| id | warehouse_code | |
| value | warehouse_name | |
| conv_id | conv_code | |
| notes | remarks | |
| capacity | capacity | |

## Migration SP
- `db_material_dev.dbo.usp_migrate_from_dbNsShizai`
- Idempotent (MERGE), transactional, with logging
- SQL file: `Doc/sql/usp_migrate_from_dbNsShizai.sql`

## Known Issues
- m_gen_kobai_jyoken columns are float type -> require CAST AS bigint for item/supplier codes
- m_sap_shiiresaki accessed via separate connection to avoid encoding issues
- 123 items have no supplier mapping (not in m_gen_kobai_jyoken)
