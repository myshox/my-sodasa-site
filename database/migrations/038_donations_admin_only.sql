-- ============================================
-- 贊助紀錄：僅管理員與超級管理員可查看
-- ============================================
-- 移除臨時開放政策，改為僅 admin / super_admin 可看全部
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. 移除臨時開放政策
DROP POLICY IF EXISTS "Temp allow all view donations" ON donations;

-- 2. 管理員可查看全部（兩種寫法並存，提高相容性）
DROP POLICY IF EXISTS "Admins can view all donations" ON donations;
CREATE POLICY "Admins can view all donations"
  ON donations FOR SELECT
  USING (public.is_admin(auth.uid()));

-- 若 管理員可以查看所有贊助記錄 不存在則建立
DROP POLICY IF EXISTS "管理員可以查看所有贊助記錄" ON donations;
CREATE POLICY "管理員可以查看所有贊助記錄"
  ON donations FOR SELECT
  USING (
    (auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin')
  );
