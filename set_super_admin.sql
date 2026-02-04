-- =====================================================
-- 設定超級管理員
-- =====================================================
-- 此腳本將指定的用戶設為超級管理員
-- 超級管理員可以管理其他管理員
-- =====================================================

-- 方法 1: 通過 Email 設定超級管理員
-- 請將 'myshoxisgood@gmail.com' 替換為您的 Email
UPDATE auth.users
SET raw_user_meta_data = 
  COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "super_admin"}'::jsonb
WHERE email = 'myshoxisgood@gmail.com';

-- =====================================================
-- 驗證設定
-- =====================================================
-- 執行以下查詢確認設定成功
SELECT 
  email,
  raw_user_meta_data->>'role' as role,
  created_at,
  last_sign_in_at
FROM auth.users
WHERE raw_user_meta_data->>'role' IN ('admin', 'super_admin')
ORDER BY created_at;

-- =====================================================
-- 其他常用指令
-- =====================================================

-- 將超級管理員降級為普通管理員
-- UPDATE auth.users
-- SET raw_user_meta_data = 
--   COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
-- WHERE email = 'your-email@example.com';

-- 移除管理員權限
-- UPDATE auth.users
-- SET raw_user_meta_data = 
--   raw_user_meta_data - 'role'
-- WHERE email = 'your-email@example.com';

-- 查看所有用戶及其角色
-- SELECT 
--   id,
--   email,
--   raw_user_meta_data->>'role' as role,
--   created_at
-- FROM auth.users
-- ORDER BY created_at DESC;
