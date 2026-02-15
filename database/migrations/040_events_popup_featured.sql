-- ============================================
-- 活動彈窗主打功能
-- ============================================
-- 新增 is_popup_featured 欄位，供後台指定「彈窗主打活動」
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS is_popup_featured BOOLEAN DEFAULT false;

COMMENT ON COLUMN public.events.is_popup_featured IS '設為 true 時，該活動會成為右下角彈窗的主打項目';
