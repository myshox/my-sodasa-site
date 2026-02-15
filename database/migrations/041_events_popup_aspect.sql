-- ============================================
-- 活動彈窗圖片比例
-- ============================================
-- 新增 popup_aspect_ratio：1:1、16:9、9:16
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS popup_aspect_ratio TEXT DEFAULT '1:1';

COMMENT ON COLUMN public.events.popup_aspect_ratio IS '彈窗圖片比例：1:1、16:9、9:16';
