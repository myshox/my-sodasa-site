-- =============================================
-- 為 donations 表加入標籤功能
-- =============================================

-- 1. 加入標籤欄位
ALTER TABLE public.donations 
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- 2. 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_donations_tags ON public.donations USING GIN(tags);

-- 3. 註解說明
COMMENT ON COLUMN public.donations.tags IS '標籤陣列，用於分類贊助者（如：VIP、常客、新手等）';

-- =============================================
-- 預設標籤規則（可在後台自動或手動設定）
-- =============================================

/*
建議標籤：
- 'vip'：單筆贊助 >= NT$ 5,000
- 'regular'：累計贊助次數 >= 3 次
- 'whale'：累計贊助 >= NT$ 10,000
- 'new'：首次贊助
- 'monthly'：每月固定贊助
*/

-- =============================================
-- 自動標籤函數（可選）
-- =============================================

-- 函數：根據金額自動加上 VIP 標籤
CREATE OR REPLACE FUNCTION auto_tag_vip()
RETURNS TRIGGER AS $$
BEGIN
    -- 如果單筆贊助 >= 5000，自動加上 VIP 標籤
    IF NEW.amount >= 5000 AND NOT ('vip' = ANY(NEW.tags)) THEN
        NEW.tags := array_append(NEW.tags, 'vip');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 觸發器：插入或更新時自動檢查
CREATE TRIGGER trigger_auto_tag_vip
BEFORE INSERT OR UPDATE ON public.donations
FOR EACH ROW
EXECUTE FUNCTION auto_tag_vip();

-- =============================================
-- 自動標記常客（累計 3 次以上）
-- =============================================

-- 函數：檢查並標記常客
CREATE OR REPLACE FUNCTION check_and_tag_regular()
RETURNS TRIGGER AS $$
DECLARE
    donation_count INT;
BEGIN
    -- 計算該 email 的贊助次數
    SELECT COUNT(*) INTO donation_count
    FROM public.donations
    WHERE email = NEW.email;
    
    -- 如果 >= 3 次，更新該 email 的所有贊助記錄加上 'regular' 標籤
    IF donation_count >= 3 THEN
        UPDATE public.donations
        SET tags = CASE 
            WHEN 'regular' = ANY(tags) THEN tags
            ELSE array_append(tags, 'regular')
        END
        WHERE email = NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 觸發器：插入後檢查
CREATE TRIGGER trigger_check_regular
AFTER INSERT ON public.donations
FOR EACH ROW
EXECUTE FUNCTION check_and_tag_regular();

-- =============================================
-- 查詢範例
-- =============================================

-- 1. 查詢所有 VIP
-- SELECT * FROM donations WHERE 'vip' = ANY(tags);

-- 2. 查詢所有常客
-- SELECT * FROM donations WHERE 'regular' = ANY(tags);

-- 3. 查詢同時是 VIP 和常客的
-- SELECT * FROM donations WHERE 'vip' = ANY(tags) AND 'regular' = ANY(tags);

-- 4. 統計各標籤數量
-- SELECT unnest(tags) as tag, COUNT(*) as count
-- FROM donations
-- GROUP BY tag
-- ORDER BY count DESC;

-- 5. 為特定用戶手動加上標籤
-- UPDATE donations
-- SET tags = array_append(tags, 'monthly')
-- WHERE email = 'user@example.com';

-- 6. 移除特定標籤
-- UPDATE donations
-- SET tags = array_remove(tags, 'vip')
-- WHERE email = 'user@example.com';

-- =============================================
-- 測試數據（可選）
-- =============================================

-- 為高額贊助加上 VIP 標籤
UPDATE public.donations
SET tags = array_append(tags, 'vip')
WHERE amount >= 5000 AND NOT ('vip' = ANY(tags));

-- 為多次贊助者加上常客標籤
WITH regular_users AS (
    SELECT email
    FROM public.donations
    GROUP BY email
    HAVING COUNT(*) >= 3
)
UPDATE public.donations d
SET tags = CASE 
    WHEN 'regular' = ANY(d.tags) THEN d.tags
    ELSE array_append(d.tags, 'regular')
END
FROM regular_users r
WHERE d.email = r.email;

COMMENT ON TABLE public.donations IS '贊助紀錄表：包含標籤系統，可自動或手動標記 VIP、常客等';
