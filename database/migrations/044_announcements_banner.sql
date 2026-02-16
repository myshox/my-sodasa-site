-- ============================================
-- 公告橫幅系統
-- ============================================
-- 首頁公告橫幅，後台可新增、編輯、啟用/停用
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

CREATE TABLE IF NOT EXISTS public.announcements (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    subtitle TEXT,
    link TEXT DEFAULT '/events',
    icon TEXT DEFAULT 'megaphone',
    badge TEXT DEFAULT 'NEW',
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.announcements IS '首頁公告橫幅';
COMMENT ON COLUMN public.announcements.link IS '點擊後導向的路徑，如 /guides 或 /events';
COMMENT ON COLUMN public.announcements.icon IS '圖示名稱：megaphone, bookopen, gift, star';
COMMENT ON COLUMN public.announcements.badge IS '左側徽章文字，如 NEW、HOT、限時';

-- 允許所有人讀取
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "announcements_select" ON public.announcements
    FOR SELECT USING (true);

CREATE POLICY "announcements_admin_all" ON public.announcements
    FOR ALL USING (
        (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin', 'super_admin')
    );
