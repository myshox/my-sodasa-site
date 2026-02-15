-- ============================================
-- 活動是否顯示於彈窗
-- ============================================
-- 新增 show_in_popup：設為 false 時，該活動不會出現在右下角彈窗
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS show_in_popup BOOLEAN DEFAULT true;

COMMENT ON COLUMN public.events.show_in_popup IS 'false 時不顯示於右下角活動彈窗，預設 true';
