-- ============================================
-- 攻略表 RLS：改為用 JWT user_metadata 判斷管理員
-- ============================================
-- 原因：RLS 違規 42501，可能為 auth.users 查詢在 RLS 情境下不如 JWT 穩定
--      前端登入後 JWT 內含 user_metadata.role，直接用 JWT 判斷
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 刪除舊的「管理員可操作」政策（保留「所有人可看已發布」）
DROP POLICY IF EXISTS "Admins can view all guides" ON guides;
DROP POLICY IF EXISTS "Admins can insert guides" ON guides;
DROP POLICY IF EXISTS "Admins can update guides" ON guides;
DROP POLICY IF EXISTS "Admins can delete guides" ON guides;

-- 輔助：當前 JWT 的 role 是否為管理員
CREATE OR REPLACE FUNCTION public.is_guide_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin'),
    false
  );
$$;

-- 重新建立：用 JWT user_metadata 判斷
CREATE POLICY "Admins can view all guides"
  ON guides FOR SELECT
  USING (public.is_guide_admin());

CREATE POLICY "Admins can insert guides"
  ON guides FOR INSERT
  WITH CHECK (public.is_guide_admin());

CREATE POLICY "Admins can update guides"
  ON guides FOR UPDATE
  USING (public.is_guide_admin());

CREATE POLICY "Admins can delete guides"
  ON guides FOR DELETE
  USING (public.is_guide_admin());

-- ============================================
-- 注意
-- ============================================
-- 1. 若仍 403：請確認該帳號在 Auth 的 user_metadata 有 role = 'admin' 或 'super_admin'
--    （Supabase Dashboard → Authentication → Users → 該用戶 → raw_user_meta_data）
-- 2. 修改 role 後請重新登入後台，讓新 JWT 帶上 role
-- ============================================
