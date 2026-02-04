-- ============================================
-- 蘇打石器 - 贊助紀錄表建立腳本
-- ============================================
-- 用途：建立 donations 表及相關設定
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. 建立贊助紀錄表
CREATE TABLE IF NOT EXISTS donations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  game_account TEXT NOT NULL,
  amount INTEGER NOT NULL,
  plan_name TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  processed_at TIMESTAMP WITH TIME ZONE,
  notes TEXT
);

-- 2. 建立索引（提升查詢效能）
CREATE INDEX IF NOT EXISTS idx_donations_user_id ON donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_email ON donations(email);
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON donations(created_at DESC);

-- 3. 啟用 Row Level Security
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;

-- 4. 刪除舊政策（如果存在）
DROP POLICY IF EXISTS "Users can view own donations" ON donations;
DROP POLICY IF EXISTS "Users can insert own donations" ON donations;
DROP POLICY IF EXISTS "Admins can view all donations" ON donations;
DROP POLICY IF EXISTS "Admins can update donations" ON donations;

-- 5. 建立 RLS 政策

-- 政策 1：玩家可以查看自己的贊助紀錄
CREATE POLICY "Users can view own donations"
  ON donations
  FOR SELECT
  USING (auth.uid() = user_id);

-- 政策 2：玩家可以新增自己的贊助紀錄
CREATE POLICY "Users can insert own donations"
  ON donations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 政策 3：管理員可以查看所有贊助紀錄
CREATE POLICY "Admins can view all donations"
  ON donations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- 政策 4：管理員可以更新贊助紀錄
CREATE POLICY "Admins can update donations"
  ON donations
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- 6. 建立觸發器：自動更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_donations_updated_at ON donations;

CREATE TRIGGER update_donations_updated_at
  BEFORE UPDATE ON donations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 完成！現在可以使用 donations 表了
-- ============================================
