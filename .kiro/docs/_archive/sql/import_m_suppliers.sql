-- ============================================
-- Import m_suppliers from dbNsShizai.m_sap_shiiresaki
-- Aligned with 仕入先得意先一覧.xlsx columns
-- Execute in: db_material_dev
-- ============================================
USE db_material_dev;
GO

-- Ensure table is empty
DELETE FROM m_suppliers;
DBCC CHECKIDENT ('m_suppliers', RESEED, 0);
GO

-- Import from m_sap_shiiresaki
-- Excel columns -> m_sap_shiiresaki columns -> m_suppliers columns:
--   種類         -> (hardcode '仕入先')  -> supplier_type
--   会社         -> [会社ｺｰﾄﾞ]           -> company_code
--   コード       -> [仕入先ｺｰﾄﾞ]         -> supplier_code
--   正式名称     -> [正式名称]            -> formal_name
--   支店部課名   -> [支店部課名]          -> branch_name
--   略称         -> [略称]               -> supplier_name
--   口座名義     -> (not in source)      -> account_name (NULL)
--   郵便番号     -> [郵便番号]            -> zip_code
--   住所１       -> [住所１]              -> address
--   住所２       -> [住所２]              -> address_2
--   電話番号     -> [電話番号]            -> tel
--   FAX番号      -> [FAX番号]             -> fax
--   登録番号     -> (not in source)      -> registration_no (NULL)
--   自動FAX使用区分 -> (not in source)   -> auto_fax_type (NULL)
--   登録日       -> (not in source)      -> registered_on (NULL)

INSERT INTO m_suppliers (
    supplier_type,
    company_code,
    supplier_code,
    formal_name,
    branch_name,
    supplier_name,
    zip_code,
    address,
    address_2,
    tel,
    fax,
    is_active,
    created_at,
    updated_at
)
SELECT
    N'仕入先'                           AS supplier_type,
    LTRIM(RTRIM(s.[会社ｺｰﾄﾞ]))          AS company_code,
    LTRIM(RTRIM(s.[仕入先ｺｰﾄﾞ]))        AS supplier_code,
    s.[正式名称]                         AS formal_name,
    s.[支店部課名]                       AS branch_name,
    s.[略称]                             AS supplier_name,
    s.[郵便番号]                         AS zip_code,
    s.[住所１]                           AS address,
    s.[住所２]                           AS address_2,
    s.[電話番号]                         AS tel,
    s.[FAX番号]                          AS fax,
    1                                    AS is_active,
    GETUTCDATE()                         AS created_at,
    GETUTCDATE()                         AS updated_at
FROM dbNsShizai.dbo.m_sap_shiiresaki s
WHERE s.[仕入先ｺｰﾄﾞ] IS NOT NULL
  AND s.[仕入先ｺｰﾄﾞ] <> ''
  AND s.[略称] IS NOT NULL
  AND s.[略称] <> '';
GO

-- Summary
SELECT
    COUNT(*) AS total_suppliers,
    COUNT(DISTINCT supplier_code) AS distinct_codes,
    COUNT(DISTINCT company_code) AS distinct_companies
FROM m_suppliers;
GO

-- Sample data
SELECT TOP 10
    id, supplier_type, company_code, supplier_code,
    formal_name, branch_name, supplier_name,
    zip_code, tel, fax
FROM m_suppliers
ORDER BY id;
GO

PRINT 'Import completed.';
GO
