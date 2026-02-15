-- ============================================
-- 贊助紀錄看不到 - RLS 修復
-- ============================================
-- 原因：034 啟用 RLS 後，部分紀錄因 user_id/email 不符政策而被隱藏
-- 解決：補充「依 email 匹配」政策，讓舊資料也能顯示
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. 補充：用戶可查看「email 符合本人」的贊助紀錄（與既有 user_id 政策並存）
--    （舊資料可能 user_id 為空或未關聯，但 email 有值）
DROP POLICY IF EXISTS "Users can view donations by email" ON donations;
CREATE POLICY "Users can view donations by email"
  ON donations FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND email IS NOT NULL
    AND LOWER(TRIM(email)) = LOWER(TRIM((SELECT email FROM auth.users WHERE id = auth.uid())))
  );

-- 2. 確保管理員（含 super_admin）可查看全部
--    使用 JWT user_metadata 判斷（與 guides 表相同，較穩定）
DROP POLICY IF EXISTS "Admins can view all donations" ON donations;
CREATE POLICY "Admins can view all donations"
  ON donations FOR SELECT
  USING (
    (auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin')
  );

