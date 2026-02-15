-- ============================================
-- 修復 guides 表 RLS 42501（new row violates row-level security policy）
-- ============================================
-- 原因：政策只檢查 auth.users.raw_user_meta_data，若未同步或 JWT 未帶 role 會失敗
-- 做法：用函數統一判斷「是否為管理員」，並以 JWT user_metadata 為輔
-- 執行：Supabase Dashboard → SQL Editor → 貼上並執行
-- ============================================

-- 1. 建立輔助函數：判斷目前登入者是否為管理員（先看 JWT，再看 auth.users）
CREATE OR REPLACE FUNCTION public.is_guides_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'user_metadata' ->> 'role') IN ('admin', 'super_admin'),
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );
$$;

-- 2. 刪除舊的 guides 管理員政策（避免重複）
DROP POLICY IF EXISTS "Admins can view all guides" ON guides;
DROP POLICY IF EXISTS "Admins can insert guides" ON guides;
DROP POLICY IF EXISTS "Admins can update guides" ON guides;
DROP POLICY IF EXISTS "Admins can delete guides" ON guides;

-- 3. 用函數重新建立政策
CREATE POLICY "Admins can view all guides"
  ON guides FOR SELECT
  USING (public.is_guides_admin());

CREATE POLICY "Admins can insert guides"
  ON guides FOR INSERT
  WITH CHECK (public.is_guides_admin());

CREATE POLICY "Admins can update guides"
  ON guides FOR UPDATE
  USING (public.is_guides_admin());

CREATE POLICY "Admins can delete guides"
  ON guides FOR DELETE
  USING (public.is_guides_admin());

-- 4. 驗證：列出目前 guides 的 RLS 政策
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'guides'
ORDER BY policyname;

-- ============================================
-- 若仍 403 / 42501，請確認：
-- 1. 已用「後台登入」用 Supabase Auth 登入（非僅記住帳號）
-- 2. 該帳號在 auth.users 的 raw_user_meta_data 有 role：執行 set_admin.sql 或
--    UPDATE auth.users SET raw_user_meta_data = raw_user_meta_data || '{"role":"admin"}'::jsonb WHERE email = '您的後台登入信箱';
-- ============================================
