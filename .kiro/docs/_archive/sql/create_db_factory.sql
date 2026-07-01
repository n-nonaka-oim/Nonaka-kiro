-- ============================================
-- Create db_factory_dev and migrate shared masters
-- Execute in: master
-- ============================================

-- 1. Create database
USE master;
GO
IF DB_ID('db_factory_dev') IS NULL
    CREATE DATABASE db_factory_dev;
GO

USE db_factory_dev;
GO

-- 2. Create shared master tables
IF OBJECT_ID('m_departments','U') IS NULL
CREATE TABLE m_departments (
    id                INT IDENTITY(1,1) PRIMARY KEY,
    department_code   NVARCHAR(50)  NOT NULL,
    department_name   NVARCHAR(50)  NOT NULL,
    sort_id           INT           NULL,
    is_active         BIT           NOT NULL DEFAULT 1,
    created_at        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT uq_m_departments_01 UNIQUE (department_code)
);
GO

IF OBJECT_ID('m_warehouses','U') IS NULL
CREATE TABLE m_warehouses (
    id                INT IDENTITY(1,1) PRIMARY KEY,
    warehouse_code    NVARCHAR(10)  NOT NULL,
    warehouse_name    NVARCHAR(50)  NOT NULL,
    is_active         BIT           NOT NULL DEFAULT 1,
    created_at        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT uq_m_warehouses_01 UNIQUE (warehouse_code)
);
GO

IF OBJECT_ID('m_suppliers','U') IS NULL
CREATE TABLE m_suppliers (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    supplier_type       NVARCHAR(10)  NULL,
    company_code        NVARCHAR(10)  NULL,
    supplier_code       NVARCHAR(20)  NOT NULL,
    formal_name         NVARCHAR(256) NULL,
    branch_name         NVARCHAR(256) NULL,
    supplier_name       NVARCHAR(256) NOT NULL,
    account_name        NVARCHAR(256) NULL,
    zip_code            NVARCHAR(10)  NULL,
    address             NVARCHAR(256) NULL,
    address_2           NVARCHAR(256) NULL,
    tel                 NVARCHAR(20)  NULL,
    fax                 NVARCHAR(20)  NULL,
    registration_no     NVARCHAR(20)  NULL,
    auto_fax_type       NVARCHAR(10)  NULL,
    registered_on       DATE          NULL,
    is_deleted_company  BIT           NOT NULL DEFAULT 0,
    is_deleted_common   BIT           NOT NULL DEFAULT 0,
    is_active           BIT           NOT NULL DEFAULT 1,
    created_at          DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT uq_m_suppliers_01 UNIQUE (supplier_code)
);
GO

IF OBJECT_ID('m_delivery_locations','U') IS NULL
CREATE TABLE m_delivery_locations (
    id                INT IDENTITY(1,1) PRIMARY KEY,
    department_id     INT           NULL,
    location_name     NVARCHAR(50)  NOT NULL,
    sort_id           INT           NULL,
    remarks           NVARCHAR(50)  NULL,
    created_at        DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at        DATETIME      NOT NULL DEFAULT GETUTCDATE()
);
GO

-- 3. Copy data from db_material_dev (preserve IDs)
SET IDENTITY_INSERT db_factory_dev.dbo.m_departments ON;
INSERT INTO db_factory_dev.dbo.m_departments (id, department_code, department_name, sort_id, is_active, created_at, updated_at)
SELECT id, department_code, department_name, sort_id, is_active, created_at, updated_at
FROM db_material_dev.dbo.m_departments
WHERE id NOT IN (SELECT id FROM db_factory_dev.dbo.m_departments);
SET IDENTITY_INSERT db_factory_dev.dbo.m_departments OFF;
GO

SET IDENTITY_INSERT db_factory_dev.dbo.m_warehouses ON;
INSERT INTO db_factory_dev.dbo.m_warehouses (id, warehouse_code, warehouse_name, is_active, created_at, updated_at)
SELECT id, warehouse_code, warehouse_name, is_active, created_at, updated_at
FROM db_material_dev.dbo.m_warehouses
WHERE id NOT IN (SELECT id FROM db_factory_dev.dbo.m_warehouses);
SET IDENTITY_INSERT db_factory_dev.dbo.m_warehouses OFF;
GO

SET IDENTITY_INSERT db_factory_dev.dbo.m_suppliers ON;
INSERT INTO db_factory_dev.dbo.m_suppliers (id, supplier_type, company_code, supplier_code, formal_name, branch_name, supplier_name, account_name, zip_code, address, address_2, tel, fax, registration_no, auto_fax_type, registered_on, is_deleted_company, is_deleted_common, is_active, created_at, updated_at)
SELECT id, supplier_type, company_code, supplier_code, formal_name, branch_name, supplier_name, account_name, zip_code, address, address_2, tel, fax, registration_no, auto_fax_type, registered_on, is_deleted_company, is_deleted_common, is_active, created_at, updated_at
FROM db_material_dev.dbo.m_suppliers
WHERE id NOT IN (SELECT id FROM db_factory_dev.dbo.m_suppliers);
SET IDENTITY_INSERT db_factory_dev.dbo.m_suppliers OFF;
GO

SET IDENTITY_INSERT db_factory_dev.dbo.m_delivery_locations ON;
INSERT INTO db_factory_dev.dbo.m_delivery_locations (id, department_id, location_name, sort_id, remarks, created_at, updated_at)
SELECT id, department_id, location_name, sort_id, remarks, created_at, updated_at
FROM db_material_dev.dbo.m_delivery_locations
WHERE id NOT IN (SELECT id FROM db_factory_dev.dbo.m_delivery_locations);
SET IDENTITY_INSERT db_factory_dev.dbo.m_delivery_locations OFF;
GO

-- 4. Summary
SELECT 'db_factory_dev' AS db_name,
    (SELECT COUNT(*) FROM m_departments) AS departments,
    (SELECT COUNT(*) FROM m_warehouses) AS warehouses,
    (SELECT COUNT(*) FROM m_suppliers) AS suppliers,
    (SELECT COUNT(*) FROM m_delivery_locations) AS delivery_locations;
GO

PRINT 'db_factory_dev created and data migrated.';
PRINT 'Next: Update appsettings.json with "FactoryDb" connection string.';
PRINT 'Next: Update MaterialModule to reference db_factory_dev for shared masters.';
GO
