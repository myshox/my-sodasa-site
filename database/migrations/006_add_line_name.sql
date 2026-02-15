-- ============================================
-- 蘇打石器 - 新增 LINE 名稱欄位
-- ============================================
-- 用途：在 donations 表新增 line_name 欄位
-- 執行位置：Supabase Dashboard → SQL Editor
-- 日期：2026-02-01
-- ============================================

-- 新增 line_name 欄位（選填）
ALTER TABLE donations
ADD COLUMN IF NOT EXISTS line_name TEXT;

-- 新增註解說明
COMMENT ON COLUMN donations.line_name IS '玩家的 LINE 顯示名稱（選填），方便管理員查核';

-- 建立索引（提升查詢效能）
CREATE INDEX IF NOT EXISTS idx_donations_line_name ON donations(line_name);

-- ============================================
-- 驗證修改
-- ============================================

-- 查看 donations 表結構
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'donations'
ORDER BY ordinal_position;

-- ============================================
-- 完成！line_name 欄位已新增
-- ============================================
