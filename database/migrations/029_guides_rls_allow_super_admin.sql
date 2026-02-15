-- ============================================
-- 攻略表 RLS：允許 super_admin 與 admin
-- ============================================
-- 原因：007 僅允許 role = 'admin'，後台登入可用 super_admin，會導致 403
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 刪除舊政策（僅限 admin）
DROP POLICY IF EXISTS "Admins can view all guides" ON guides;
DROP POLICY IF EXISTS "Admins can insert guides" ON guides;
DROP POLICY IF EXISTS "Admins can update guides" ON guides;
DROP POLICY IF EXISTS "Admins can delete guides" ON guides;

-- 重新建立：admin 或 super_admin 皆可
CREATE POLICY "Admins can view all guides"
  ON guides FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Admins can insert guides"
  ON guides FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Admins can update guides"
  ON guides FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Admins can delete guides"
  ON guides FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );
