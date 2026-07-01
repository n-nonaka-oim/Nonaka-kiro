-- ============================================
-- m_suppliers: Align with 仕入先得意先一覧.xlsx
-- Execute in: db_material_dev
-- ============================================
USE db_material_dev;
GO

-- Drop FK references first
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name LIKE '%supplier%' AND parent_object_id = OBJECT_ID('m_items'))
BEGIN
    DECLARE @fk nvarchar(256);
    SELECT @fk = name FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID('m_items') AND name LIKE '%supplier%';
    IF @fk IS NOT NULL EXEC('ALTER TABLE m_items DROP CONSTRAINT ' + @fk);
END
GO

-- Recreate m_suppliers with full columns
IF OBJECT_ID('m_suppliers','U') IS NOT NULL
BEGIN
    -- Save existing data
    SELECT * INTO #tmp_suppliers FROM m_suppliers;
    DROP TABLE m_suppliers;
END
GO

CREATE TABLE m_suppliers (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    supplier_type       NVARCHAR(10)  NULL,          -- 種類（仕入先/得意先）
    company_code        NVARCHAR(10)  NULL,          -- 会社コード
    supplier_code       NVARCHAR(20)  NOT NULL,      -- コード
    formal_name         NVARCHAR(256) NULL,          -- 正式名称
    branch_name         NVARCHAR(256) NULL,          -- 支店部課名
    supplier_name       NVARCHAR(256) NOT NULL,      -- 略称
    account_name        NVARCHAR(256) NULL,          -- 口座名義
    zip_code            NVARCHAR(10)  NULL,          -- 郵便番号
    address             NVARCHAR(256) NULL,          -- 住所１
    address_2           NVARCHAR(256) NULL,          -- 住所２
    tel                 NVARCHAR(20)  NULL,          -- 電話番号
    fax                 NVARCHAR(20)  NULL,          -- FAX番号
    registration_no     NVARCHAR(20)  NULL,          -- 登録番号
    auto_fax_type       NVARCHAR(10)  NULL,          -- 自動FAX使用区分
    registered_on       DATE          NULL,          -- 登録日
    is_deleted_company  BIT           NOT NULL DEFAULT 0, -- 削除(会社)
    is_deleted_common   BIT           NOT NULL DEFAULT 0, -- 削除(共通)
    is_active           BIT           NOT NULL DEFAULT 1,
    created_at          DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at          DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT uq_m_suppliers_01 UNIQUE (supplier_code)
);
GO

-- Restore existing data (minimal columns)
IF OBJECT_ID('tempdb..#tmp_suppliers') IS NOT NULL
BEGIN
    SET IDENTITY_INSERT m_suppliers ON;
    INSERT INTO m_suppliers (id, supplier_code, supplier_name, is_active, created_at, updated_at)
    SELECT id, supplier_code, supplier_name, is_active, created_at, updated_at
    FROM #tmp_suppliers;
    SET IDENTITY_INSERT m_suppliers OFF;
    DROP TABLE #tmp_suppliers;
END
GO

PRINT 'm_suppliers recreated with full columns from 仕入先得意先一覧.xlsx';
GO
