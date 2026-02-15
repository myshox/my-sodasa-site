-- ============================================
-- 蘇打石器 - 新增金幣數量欄位
-- ============================================
-- 用途：在 donations 表新增 coins 欄位，記錄贊助獲得的金幣數量
-- 執行位置：Supabase Dashboard → SQL Editor
-- 日期：2026-02-01
-- ============================================

-- 新增 coins 欄位
ALTER TABLE donations
ADD COLUMN IF NOT EXISTS coins INTEGER;

-- 新增註解說明
COMMENT ON COLUMN donations.coins IS '贊助獲得的金幣數量（含紅利）';

-- 建立索引（方便統計）
CREATE INDEX IF NOT EXISTS idx_donations_coins ON donations(coins);

-- 更新現有資料（根據金額計算金幣，假設 100元=10000幣+紅利）
-- 這裡需要根據實際方案調整
UPDATE donations
SET coins = CASE
    WHEN amount = 100 THEN 10000
    WHEN amount = 300 THEN 32000
    WHEN amount = 500 THEN 55000
    WHEN amount = 1000 THEN 115000
    WHEN amount = 3000 THEN 360000
    WHEN amount = 5000 THEN 625000
    WHEN amount = 10000 THEN 1300000
    ELSE amount * 100  -- 預設：1元 = 100金幣
END
WHERE coins IS NULL;

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

-- 查看更新後的資料
SELECT 
    game_account,
    amount,
    coins,
    status
FROM donations
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 完成！coins 欄位已新增
-- ============================================
