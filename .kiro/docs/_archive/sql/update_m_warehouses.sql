-- ============================================
-- Update m_warehouses from dbNsASP.m_soko
-- Execute in: db_factory_dev
-- ============================================
USE db_factory_dev;
GO

-- 1. Add missing columns
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='m_warehouses' AND COLUMN_NAME='conv_code')
    ALTER TABLE m_warehouses ADD conv_code NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='m_warehouses' AND COLUMN_NAME='remarks')
    ALTER TABLE m_warehouses ADD remarks NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='m_warehouses' AND COLUMN_NAME='capacity')
    ALTER TABLE m_warehouses ADD capacity DECIMAL(10,2) NULL;
GO

-- 2. Update from m_soko
UPDATE w SET
    w.warehouse_name = s.value,
    w.conv_code = s.conv_id,
    w.remarks = s.notes,
    w.capacity = s.capacity,
    w.updated_at = GETUTCDATE()
FROM m_warehouses w
INNER JOIN dbNsASP.dbo.m_soko s ON w.warehouse_code = s.id;
GO

-- 3. Insert missing
INSERT INTO m_warehouses (warehouse_code, warehouse_name, conv_code, remarks, capacity, is_active)
SELECT s.id, s.value, s.conv_id, s.notes, s.capacity, 1
FROM dbNsASP.dbo.m_soko s
WHERE s.id NOT IN (SELECT warehouse_code FROM m_warehouses)
  AND s.id IS NOT NULL AND s.id <> '';
GO

-- 4. Summary
SELECT id, warehouse_code, warehouse_name, conv_code, remarks, capacity
FROM m_warehouses ORDER BY warehouse_code;
GO
