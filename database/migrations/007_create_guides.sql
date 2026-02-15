-- ============================================
-- 蘇打石器 - 建立活動攻略表
-- ============================================
-- 用途：儲存活動攻略內容（支援富文本、圖片）
-- 執行位置：Supabase Dashboard → SQL Editor
-- 日期：2026-02-01
-- ============================================

-- 建立 guides 表
CREATE TABLE IF NOT EXISTS guides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,                    -- 攻略標題
    content TEXT NOT NULL,                  -- HTML 內容（含圖片 Base64）
    thumbnail TEXT,                         -- 縮圖 URL
    category TEXT DEFAULT 'general',        -- 分類：general, event, pvp, pve, beginner
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT,                       -- 作者名稱（快取）
    status TEXT DEFAULT 'draft',            -- draft, published, archived
    views INTEGER DEFAULT 0,                -- 瀏覽次數
    likes INTEGER DEFAULT 0,                -- 點讚數
    is_pinned BOOLEAN DEFAULT FALSE,        -- 是否置頂
    publish_date TIMESTAMPTZ,               -- 發布日期
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 新增註解
COMMENT ON TABLE guides IS '活動攻略表';
COMMENT ON COLUMN guides.title IS '攻略標題';
COMMENT ON COLUMN guides.content IS 'HTML 格式的攻略內容（可含 Base64 圖片）';
COMMENT ON COLUMN guides.category IS '分類：general(綜合), event(活動), pvp(PVP), pve(PVE), beginner(新手)';
COMMENT ON COLUMN guides.status IS '狀態：draft(草稿), published(已發布), archived(已封存)';

-- 建立索引
CREATE INDEX IF NOT EXISTS idx_guides_status ON guides(status);
CREATE INDEX IF NOT EXISTS idx_guides_author_id ON guides(author_id);
CREATE INDEX IF NOT EXISTS idx_guides_category ON guides(category);
CREATE INDEX IF NOT EXISTS idx_guides_created_at ON guides(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_guides_publish_date ON guides(publish_date DESC);
CREATE INDEX IF NOT EXISTS idx_guides_is_pinned ON guides(is_pinned, publish_date DESC);

-- 啟用 RLS
ALTER TABLE guides ENABLE ROW LEVEL SECURITY;

-- RLS 政策 1：所有人可查看已發布的攻略
CREATE POLICY "Anyone can view published guides"
  ON guides FOR SELECT
  USING (status = 'published');

-- RLS 政策 2：管理員可查看所有攻略
CREATE POLICY "Admins can view all guides"
  ON guides FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- RLS 政策 3：管理員可新增攻略
CREATE POLICY "Admins can insert guides"
  ON guides FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- RLS 政策 4：管理員可更新攻略
CREATE POLICY "Admins can update guides"
  ON guides FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- RLS 政策 5：管理員可刪除攻略
CREATE POLICY "Admins can delete guides"
  ON guides FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- 建立觸發器：自動更新 updated_at
CREATE TRIGGER update_guides_updated_at
  BEFORE UPDATE ON guides
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 建立觸發器：發布時自動設定 publish_date
CREATE OR REPLACE FUNCTION set_publish_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'published' AND OLD.status != 'published' THEN
    NEW.publish_date = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_guides_publish_date
  BEFORE UPDATE ON guides
  FOR EACH ROW
  EXECUTE FUNCTION set_publish_date();

-- 建立函數：增加瀏覽次數
CREATE OR REPLACE FUNCTION increment_guide_views(guide_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE guides
  SET views = views + 1
  WHERE id = guide_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 驗證
-- ============================================

-- 查看表結構
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'guides'
ORDER BY ordinal_position;

-- ============================================
-- 完成！guides 表已建立
-- ============================================
