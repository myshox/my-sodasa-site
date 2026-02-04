-- ============================================
-- 蘇打石器 - 設定管理員帳號
-- ============================================
-- 用途：將特定用戶設為管理員
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

-- 方法 1：設定單一管理員（請修改 Email）
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"admin"'
)
WHERE email = '您的Email@example.com';  -- ← 請修改這裡！

-- ============================================

-- 方法 2：一次設定多個管理員（可選）
-- 取消下方註解並修改 Email 列表
/*
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"admin"'
)
WHERE email IN (
  'admin1@example.com',  -- ← 請修改
  'admin2@example.com'   -- ← 請修改
);
*/

-- ============================================

-- 驗證：檢查所有管理員帳號
SELECT 
  email, 
  raw_user_meta_data->>'role' as role,
  created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'admin';

-- ============================================
-- 執行後應該會看到您的管理員 Email 和 role = admin
-- ============================================
