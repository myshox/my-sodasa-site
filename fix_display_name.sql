-- =====================================================
-- 修復：為超級管理員補上顯示名稱
-- =====================================================

-- 更新 myshoxisgood@gmail.com 的顯示名稱
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || '{"display_name": "系統管理員"}'::jsonb
WHERE email = 'myshoxisgood@gmail.com';

-- 驗證修復結果
SELECT 
    email, 
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name,
    created_at
FROM auth.users 
WHERE email = 'myshoxisgood@gmail.com';
