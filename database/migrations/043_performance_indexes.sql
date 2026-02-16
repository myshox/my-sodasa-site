-- ============================================
-- 效能優化：常用查詢索引
-- ============================================
-- 加速排序與篩選查詢
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- events 表
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_show_in_popup ON events(show_in_popup) WHERE show_in_popup = true;

-- donations 表
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON donations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);

-- playlist 表
CREATE INDEX IF NOT EXISTS idx_playlist_created_at ON playlist(created_at DESC);
