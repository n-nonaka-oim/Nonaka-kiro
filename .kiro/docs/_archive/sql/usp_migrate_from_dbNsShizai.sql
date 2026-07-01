-- ============================================
-- Migration SP: dbNsShizai -> db_material_dev
-- Execute in: db_material_dev
-- v4: Best practice (idempotent, MERGE, logging)
-- ============================================
USE db_material_dev;
GO

IF OBJECT_ID('usp_migrate_from_dbNsShizai','P') IS NOT NULL
    DROP PROCEDURE usp_migrate_from_dbNsShizai;
GO

CREATE PROCEDURE usp_migrate_from_dbNsShizai
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @inserted INT, @updated INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        PRINT '=== Step 1: m_suppliers from m_sap_shiiresaki ===';

        -- MERGE: insert new, update existing
        MERGE m_suppliers AS target
        USING (
            SELECT DISTINCT
                LTRIM(RTRIM(s.[仕入先ｺｰﾄﾞ])) AS supplier_code,
                s.[略称] AS supplier_name
            FROM dbNsShizai.dbo.m_sap_shiiresaki s
            WHERE s.[仕入先ｺｰﾄﾞ] IS NOT NULL AND s.[仕入先ｺｰﾄﾞ] <> ''
              AND s.[略称] IS NOT NULL AND s.[略称] <> ''
        ) AS source
        ON target.supplier_code = source.supplier_code
        WHEN MATCHED THEN
            UPDATE SET supplier_name = source.supplier_name,
                       updated_at = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (supplier_code, supplier_name, is_active, created_at, updated_at)
            VALUES (source.supplier_code, source.supplier_name, 1, GETUTCDATE(), GETUTCDATE());

        SET @inserted = @@ROWCOUNT;
        PRINT CONCAT('  m_suppliers: ', @inserted, ' rows merged');

        -- --------------------------------------------------------
        PRINT '=== Step 2: m_items.supplier_id from m_gen_kobai_jyoken ===';

        UPDATE i SET
            i.supplier_id = s.id,
            i.updated_at = GETUTCDATE()
        FROM m_items i
        INNER JOIN (
            SELECT DISTINCT
                LTRIM(RTRIM(CAST(k.[品目コード] AS nvarchar(50)))) AS item_code,
                LTRIM(RTRIM(CONVERT(nvarchar(20), CAST(k.[仕入先] AS bigint)))) AS sup_code
            FROM dbNsShizai.dbo.m_gen_kobai_jyoken k
            WHERE k.[品目コード] IS NOT NULL AND k.[仕入先] IS NOT NULL
        ) kj ON i.item_code = kj.item_code
        INNER JOIN m_suppliers s ON s.supplier_code = kj.sup_code
        WHERE i.supplier_id IS NULL OR i.supplier_id <> s.id;

        SET @updated = @@ROWCOUNT;
        PRINT CONCAT('  m_items.supplier_id: ', @updated, ' rows updated');

        -- --------------------------------------------------------
        PRINT '=== Step 3: r_item_departments from m_hinmoku ===';

        INSERT INTO r_item_departments (item_id, department_id, is_default, created_at, updated_at)
        SELECT DISTINCT i.id, d.id, 0, GETUTCDATE(), GETUTCDATE()
        FROM dbNsShizai.dbo.m_hinmoku h
        INNER JOIN m_items i ON i.item_code = h.sap_id
        INNER JOIN m_departments d ON d.department_code = h.section_id
        WHERE NOT EXISTS (
            SELECT 1 FROM r_item_departments rd
            WHERE rd.item_id = i.id AND rd.department_id = d.id
        );

        SET @inserted = @@ROWCOUNT;
        PRINT CONCAT('  r_item_departments: ', @inserted, ' rows inserted');

        -- --------------------------------------------------------
        PRINT '=== Step 4: r_item_warehouses from m_hinmoku ===';

        INSERT INTO r_item_warehouses (item_id, warehouse_id, is_default, created_at, updated_at)
        SELECT DISTINCT i.id, w.id, 0, GETUTCDATE(), GETUTCDATE()
        FROM dbNsShizai.dbo.m_hinmoku h
        INNER JOIN m_items i ON i.item_code = h.sap_id
        INNER JOIN m_warehouses w ON w.warehouse_code = h.soko_id
        WHERE NOT EXISTS (
            SELECT 1 FROM r_item_warehouses rw
            WHERE rw.item_id = i.id AND rw.warehouse_id = w.id
        );

        SET @inserted = @@ROWCOUNT;
        PRINT CONCAT('  r_item_warehouses: ', @inserted, ' rows inserted');

        -- --------------------------------------------------------
        PRINT '=== Step 5: Set default flags ===';

        -- r_item_departments: set first record as default where no default exists
        ;WITH cte_dept AS (
            SELECT id, item_id,
                   ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY id) AS rn
            FROM r_item_departments
            WHERE item_id NOT IN (
                SELECT item_id FROM r_item_departments WHERE is_default = 1
            )
        )
        UPDATE r_item_departments
        SET is_default = 1, updated_at = GETUTCDATE()
        WHERE id IN (SELECT id FROM cte_dept WHERE rn = 1);

        SET @updated = @@ROWCOUNT;
        PRINT CONCAT('  r_item_departments defaults set: ', @updated);

        -- r_item_warehouses: set first record as default where no default exists
        ;WITH cte_wh AS (
            SELECT id, item_id,
                   ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY id) AS rn
            FROM r_item_warehouses
            WHERE item_id NOT IN (
                SELECT item_id FROM r_item_warehouses WHERE is_default = 1
            )
        )
        UPDATE r_item_warehouses
        SET is_default = 1, updated_at = GETUTCDATE()
        WHERE id IN (SELECT id FROM cte_wh WHERE rn = 1);

        SET @updated = @@ROWCOUNT;
        PRINT CONCAT('  r_item_warehouses defaults set: ', @updated);

        COMMIT TRANSACTION;

        -- --------------------------------------------------------
        PRINT '=== Migration Summary ===';

        SELECT
            (SELECT COUNT(*) FROM m_suppliers) AS suppliers,
            (SELECT COUNT(*) FROM m_items WHERE supplier_id IS NOT NULL) AS items_with_supplier,
            (SELECT COUNT(*) FROM m_items) AS total_items,
            (SELECT COUNT(*) FROM r_item_departments) AS item_dept_links,
            (SELECT COUNT(*) FROM r_item_warehouses) AS item_wh_links,
            (SELECT COUNT(DISTINCT item_id) FROM r_item_departments) AS items_with_dept,
            (SELECT COUNT(DISTINCT item_id) FROM r_item_warehouses) AS items_with_wh;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT CONCAT('ERROR: ', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

-- Execute
EXEC usp_migrate_from_dbNsShizai;
GO
