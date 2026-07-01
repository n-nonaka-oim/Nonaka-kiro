# Database Schema - MaterialModule

## Database Configuration

| DB | Purpose | Connection Key | Server |
|---|---|---|---|
| db_material_dev | MaterialModule tables | MaterialDb | OJIADM23120073\DEVELOPMENT |
| db_factory_dev | Shared factory masters | FactoryDb | OJIADM23120073\DEVELOPMENT |

---

## db_material_dev Tables

### m_items (Raw Material Master)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| item_code | nvarchar(50) | NO | Item code (unique) |
| item_name | nvarchar(256) | NO | Item name |
| short_name | nvarchar(256) | YES | Short name |
| order_unit_qty | decimal(10,2) | NO | Order unit quantity (default: 1) |
| content_qty | decimal(10,2) | YES | Content per package |
| content_unit | nvarchar(3) | YES | Content unit (KG, KL, etc.) |
| package_type_id | int | YES | FK -> m_package_types |
| default_delivery_days | int | NO | Default delivery days (default: 14) |
| lead_time_days | int | NO | MRP lead time days (default: 14) |
| stock_minimum_qty | decimal(10,2) | YES | Minimum stock for alert |
| safety_stock_qty | decimal(10,2) | YES | Safety stock for MRP |
| lot_size_type | nvarchar(20) | NO | lot_for_lot / fixed_qty |
| fixed_lot_qty | decimal(10,2) | YES | Fixed lot quantity |
| receiving_unit_qty | decimal(10,2) | YES | Receiving unit quantity |
| default_order_qty | decimal(10,2) | YES | Default order quantity (avg from history) |
| warehouse_id | int | YES | Default warehouse FK |
| supplier_id | int | YES | Default supplier FK |
| department_id | int | YES | Department FK |
| brand_id | int | YES | Brand ID |
| input_lot | int | YES | Input lot |
| is_active | bit | NO | Active flag (default: 1) |
| created_at | datetime | NO | Created timestamp |
| updated_at | datetime | NO | Updated timestamp |

### m_package_types (Package Type Master)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| package_type_name | nvarchar(50) | NO | Package type name |
| created_at / updated_at | datetime | NO | Timestamps |

### m_order_statuses (Order Status Master)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| status_name | nvarchar(50) | NO | Status name |
| next_status_id | int | YES | Next status FK (self-ref) |
| restore_status_id | int | YES | Restore status FK (self-ref) |
| created_at / updated_at | datetime | NO | Timestamps |

Seed data: 1=Pending, 2=Approved, 3=Ordered, 4=Received, 5=Rejected

### m_forecast_sources (Forecast Source Master)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| source_code | nvarchar(20) | NO | Source code |
| source_name | nvarchar(50) | NO | Source name |
| is_active | bit | NO | Active flag |
| created_at / updated_at | datetime | NO | Timestamps |

Seed data: 1=manual, 2=production_plan, 3=bom_explosion

### m_bom_headers / m_bom_details (BOM - future use)
Empty tables for future production plan integration.

### t_orders (Order Data)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| order_no | nvarchar(10) | NO | Order number |
| order_line_no | nvarchar(4) | NO | Line number |
| order_date | date | NO | Order date |
| order_type | nvarchar(10) | NO | manual / auto / provisional |
| item_id | int | NO | FK -> m_items |
| item_code | nvarchar(50) | NO | Item code (snapshot) |
| item_name | nvarchar(256) | YES | Item name (snapshot) |
| order_qty | decimal(10,2) | NO | Order quantity |
| unit_content_qty | decimal(10,2) | YES | Unit content |
| total_qty | decimal(10,2) | YES | Total quantity |
| supplier_id | int | YES | FK -> m_suppliers |
| supplier_name | nvarchar(80) | YES | Supplier name (snapshot) |
| delivery_date | date | NO | Delivery date |
| warehouse_id | int | YES | FK -> m_warehouses |
| delivery_location_id | int | YES | FK -> m_delivery_locations |
| order_status_id | int | NO | FK -> m_order_statuses |
| remarks | nvarchar(256) | YES | Remarks |
| user_id | nvarchar(40) | NO | User ID |
| user_name | nvarchar(40) | YES | User name |
| approved_at | datetime | YES | Approval timestamp |
| approved_by | nvarchar(40) | YES | Approver |
| forecast_id | int | YES | FK -> t_order_forecasts |
| created_at / updated_at | datetime | NO | Timestamps |

### t_order_entries (Temporary Order Entries)
| Column | Type | Null | Description |
|---|---|---|---|
| id | int IDENTITY | PK | Primary key |
| user_id | nvarchar(40) | NO | User ID (per-user isolation) |
| item_id | int | NO | Item ID |
| item_code | nvarchar(50) | NO | Item code |
| item_name | nvarchar(256) | YES | Item name |
| order_qty | decimal(10,2) | NO | Order quantity |
| unit_content_qty | decimal(10,2) | YES | Unit content |
| delivery_date | date | YES | Delivery date |
| supplier_id | int | YES | Supplier ID |
| supplier_name | nvarchar(80) | YES | Supplier name |
| warehouse_id | int | YES | Warehouse ID |
| delivery_location_id | int | YES | Delivery location ID |
| remarks | nvarchar(256) | YES | Remarks |
| is_submitted | bit | NO | Submitted flag |
| submitted_at | datetime | YES | Submit timestamp |
| created_at | datetime | NO | Created timestamp |

### t_receivings, t_dispatches, t_stocks, t_stock_ledgers, t_consumption_forecasts, t_order_forecasts
See requirements.md for full definitions.

### r_item_departments (Item-Department Junction)
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| item_id | int FK | m_items |
| department_id | int FK | m_departments |
| is_default | bit | Default department flag |
| created_at / updated_at | datetime | |

### r_item_warehouses (Item-Warehouse Junction)
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| item_id | int FK | m_items |
| warehouse_id | int FK | m_warehouses |
| is_default | bit | Default warehouse flag |
| created_at / updated_at | datetime | |

---

## db_factory_dev Tables (Shared Masters)

### m_warehouses
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| warehouse_code | nvarchar(50) | Warehouse code (unique) |
| warehouse_name | nvarchar(50) | Warehouse name |
| conv_code | nvarchar(50) | Conversion code |
| remarks | nvarchar(50) | Remarks |
| capacity | decimal(10,2) | Capacity |
| is_active | bit | Active flag |
| created_at / updated_at | datetime | |

### m_departments
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| department_code | nvarchar(50) | Department code (unique) |
| department_name | nvarchar(50) | Department name |
| sort_id | int | Sort order |
| is_active | bit | Active flag |
| created_at / updated_at | datetime | |

### m_suppliers
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| supplier_type | nvarchar(10) | Type |
| company_code | nvarchar(10) | Company code |
| supplier_code | nvarchar(20) | Supplier code (unique) |
| formal_name | nvarchar(256) | Formal name |
| branch_name | nvarchar(256) | Branch name |
| supplier_name | nvarchar(256) | Short name |
| account_name | nvarchar(256) | Account name |
| zip_code | nvarchar(10) | Zip code |
| address | nvarchar(256) | Address 1 |
| address_2 | nvarchar(256) | Address 2 |
| tel | nvarchar(20) | Phone |
| fax | nvarchar(20) | Fax |
| registration_no | nvarchar(20) | Registration number |
| auto_fax_type | nvarchar(10) | Auto fax type |
| registered_on | date | Registration date |
| is_deleted_company | bit | Deleted (company) |
| is_deleted_common | bit | Deleted (common) |
| is_active | bit | Active flag |
| created_at / updated_at | datetime | |

### m_delivery_locations
| Column | Type | Description |
|---|---|---|
| id | int IDENTITY PK | |
| department_id | int FK (nullable) | Department |
| location_name | nvarchar(50) | Location name |
| sort_id | int | Sort order |
| remarks | nvarchar(50) | Remarks |
| created_at / updated_at | datetime | |
