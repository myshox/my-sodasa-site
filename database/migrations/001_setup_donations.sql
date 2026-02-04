-- ============================================
-- 蘇打石器 - donations 表補充設定
-- ============================================
-- 用途：為已建立的 donations 表補上完整設定
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. 新增 Foreign Keys（外鍵關聯）
-- ============================================

-- 外鍵 1：user_id 關聯到 auth.users
ALTER TABLE donations
ADD CONSTRAINT donations_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- 外鍵 2：processed_by 關聯到 auth.users
ALTER TABLE donations
ADD CONSTRAINT donations_processed_by_fkey 
FOREIGN KEY (processed_by) 
REFERENCES auth.users(id) 
ON DELETE SET NULL;

-- ============================================
-- 2. 建立索引（提升查詢效能）
-- ============================================

CREATE INDEX IF NOT EXISTS idx_donations_user_id ON donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_email ON donations(email);
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON donations(created_at DESC);

-- ============================================
-- 3. 啟用 RLS（Row Level Security）
-- ============================================

ALTER TABLE donations ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. 建立 RLS Policies（權限控制）
-- ============================================

-- 刪除舊政策（如果存在）
DROP POLICY IF EXISTS "Users can view own donations" ON donations;
DROP POLICY IF EXISTS "Users can insert own donations" ON donations;
DROP POLICY IF EXISTS "Admins can view all donations" ON donations;
DROP POLICY IF EXISTS "Admins can update donations" ON donations;

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

-- 政策 4：管理員可以更新贊助紀錄（標記為已處理、新增備註等）
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

-- ============================================
-- 5. 建立觸發器：自動更新 updated_at
-- ============================================

-- 建立觸發器函數
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 刪除舊觸發器（如果存在）
DROP TRIGGER IF EXISTS update_donations_updated_at ON donations;

-- 建立新觸發器
CREATE TRIGGER update_donations_updated_at
  BEFORE UPDATE ON donations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 6. 驗證設定
-- ============================================

-- 查看 Foreign Keys
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'donations';

-- 查看 Indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'donations'
ORDER BY indexname;

-- 查看 RLS Policies
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'donations'
ORDER BY policyname;

-- ============================================
-- 完成！donations 表已完整設定
-- ============================================
