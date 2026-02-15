-- ============================================
-- 修復 donations 更新/刪除時 42501 permission denied for table users
-- ============================================
-- 原因：現有 UPDATE/DELETE 政策使用 is_admin(auth.uid())，內部查詢 auth.users。
--       在部分 Supabase 環境中，authenticated 角色無法透過該函數讀取 auth.users。
-- 做法：改為使用 JWT user_metadata 判斷（與 036/038 SELECT 政策一致），
--       不涉及 auth.users 查詢，避免 42501。
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. 更新「管理員可以更新贊助記錄」：改用 JWT 判斷
DROP POLICY IF EXISTS "管理員可以更新贊助記錄" ON donations;
DROP POLICY IF EXISTS "Admins can update donations" ON donations;
CREATE POLICY "管理員可以更新贊助記錄"
  ON donations FOR UPDATE
  USING (
    (auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin')
  );

-- 2. 更新「管理員可以刪除贊助記錄」：改用 JWT 判斷
DROP POLICY IF EXISTS "管理員可以刪除贊助記錄" ON donations;
DROP POLICY IF EXISTS "Admins can delete donations" ON donations;
CREATE POLICY "管理員可以刪除贊助記錄"
  ON donations FOR DELETE
  USING (
    (auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin')
  );

-- ============================================
-- 驗證：列出 donations 的 RLS 政策
-- ============================================
-- SELECT schemaname, tablename, policyname, cmd, qual
-- FROM pg_policies
-- WHERE tablename = 'donations'
-- ORDER BY policyname;
