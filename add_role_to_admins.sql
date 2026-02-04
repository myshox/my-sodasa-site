-- =====================================================
-- 為 admins 表添加 role 欄位
-- =====================================================
-- 此腳本為 admins 表添加角色欄位
-- 支援 'admin' 和 'super_admin' 兩種角色
-- =====================================================

-- 1. 添加 role 欄位
ALTER TABLE admins 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'admin';

-- 2. 添加檢查約束（確保只能是 admin 或 super_admin）
ALTER TABLE admins 
ADD CONSTRAINT admins_role_check 
CHECK (role IN ('admin', 'super_admin'));

-- 3. 為現有管理員設定預設角色
UPDATE admins
SET role = 'admin'
WHERE role IS NULL;

-- =====================================================
-- 驗證設定
-- =====================================================
-- 執行以下查詢確認更新成功
SELECT 
  id,
  username,
  role,
  created_at
FROM admins
ORDER BY created_at DESC;

-- =====================================================
-- 設定第一個管理員為超級管理員（可選）
-- =====================================================
-- 如果您想將第一個創建的管理員設為超級管理員，執行：
-- UPDATE admins
-- SET role = 'super_admin'
-- WHERE id = (SELECT id FROM admins ORDER BY created_at LIMIT 1);

-- 或者通過用戶名設定：
-- UPDATE admins
-- SET role = 'super_admin'
-- WHERE username = '您的管理員帳號';
