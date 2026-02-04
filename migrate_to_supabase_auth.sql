-- =====================================================
-- Supabase Auth 完整遷移方案
-- 目的：移除 admins 表，統一使用 Supabase Auth
-- =====================================================

-- =====================================================
-- 步驟 1：將現有 admins 表的管理員遷移到 Supabase Auth
-- =====================================================
-- 注意：此步驟需要手動執行，因為 Supabase Auth 創建用戶需要使用 API

-- 執行方式：在 Supabase Dashboard 的 Authentication > Users 頁面
-- 手動為每個管理員創建帳號，並設定以下資訊：

/*
管理員遷移清單（範例）：

1. 超級管理員
   Email: myshoxisgood@gmail.com
   Password: [設定新密碼]
   User Metadata: 
   {
     "role": "super_admin",
     "display_name": "系統管理員"
   }

2. 一般管理員（如果有）
   Email: admin@example.com
   Password: [設定新密碼]
   User Metadata:
   {
     "role": "admin",
     "display_name": "管理員"
   }
*/

-- =====================================================
-- 步驟 2：確認所有管理員已遷移到 Supabase Auth
-- =====================================================
-- 執行以下查詢確認管理員帳號：

-- 查看所有管理員（在 SQL Editor 執行）
SELECT 
    id,
    email,
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name,
    created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' IN ('admin', 'super_admin')
ORDER BY created_at;

-- =====================================================
-- 步驟 3：備份 admins 表（以防萬一）
-- =====================================================
-- 創建備份表
CREATE TABLE IF NOT EXISTS admins_backup AS
SELECT * FROM admins;

-- 驗證備份
SELECT COUNT(*) as backup_count FROM admins_backup;

-- =====================================================
-- 步驟 4：更新 audit_logs 表結構
-- =====================================================
-- audit_logs 原本依賴 admins 表，需要調整為使用 Supabase Auth

-- 4.1 添加新欄位（如果尚未存在）
ALTER TABLE audit_logs 
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- 4.2 遷移現有的 audit logs 資料（可選）
-- 如果需要保留舊的審計記錄，可以將 admin_username 保留作為歷史記錄

-- =====================================================
-- 步驟 5：刪除 admins 表的外鍵依賴
-- =====================================================
-- 檢查是否有其他表依賴 admins 表
SELECT
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = 'admins';

-- 如果有依賴，需要先刪除外鍵約束

-- =====================================================
-- 步驟 6：安全刪除 admins 表
-- =====================================================
-- ⚠️ 警告：執行此步驟前請確認：
-- 1. 所有管理員已成功遷移到 Supabase Auth
-- 2. 已創建備份（admins_backup 表）
-- 3. 前端登入邏輯已更新為使用 Supabase Auth
-- 4. 已經測試過新的登入流程

-- 刪除 admins 表（請謹慎執行！）
-- DROP TABLE IF EXISTS admins CASCADE;

-- ⚠️ 建議：先將表重命名而不是立即刪除，觀察一段時間後再刪除
ALTER TABLE admins RENAME TO admins_deprecated;

-- 可以在確認系統運作正常後（例如 7-30 天後），再執行：
-- DROP TABLE admins_deprecated;

-- =====================================================
-- 步驟 7：創建輔助函數和觸發器
-- =====================================================

-- 7.1 創建函數：檢查用戶是否為管理員
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE id = user_id 
        AND raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7.2 創建函數：檢查用戶是否為超級管理員
CREATE OR REPLACE FUNCTION is_super_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE id = user_id 
        AND raw_user_meta_data->>'role' = 'super_admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7.3 創建函數：獲取管理員資訊
CREATE OR REPLACE FUNCTION get_admin_info(user_id UUID)
RETURNS TABLE (
    id UUID,
    email TEXT,
    role TEXT,
    display_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email::TEXT,
        (u.raw_user_meta_data->>'role')::TEXT as role,
        (u.raw_user_meta_data->>'display_name')::TEXT as display_name
    FROM auth.users u
    WHERE u.id = user_id
    AND u.raw_user_meta_data->>'role' IN ('admin', 'super_admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 步驟 8：更新 RLS 政策
-- =====================================================

-- 8.1 更新 donations 表的 RLS 政策
DROP POLICY IF EXISTS "管理員可以查看所有贊助記錄" ON donations;
DROP POLICY IF EXISTS "管理員可以更新贊助記錄" ON donations;
DROP POLICY IF EXISTS "管理員可以刪除贊助記錄" ON donations;

-- 使用新的管理員檢查函數
CREATE POLICY "管理員可以查看所有贊助記錄" ON donations
    FOR SELECT
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以更新贊助記錄" ON donations
    FOR UPDATE
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以刪除贊助記錄" ON donations
    FOR DELETE
    USING (is_admin(auth.uid()));

-- 8.2 更新 audit_logs 表的 RLS 政策
DROP POLICY IF EXISTS "管理員可以查看審計日誌" ON audit_logs;

CREATE POLICY "管理員可以查看審計日誌" ON audit_logs
    FOR SELECT
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以寫入審計日誌" ON audit_logs
    FOR INSERT
    WITH CHECK (is_admin(auth.uid()));

-- 8.3 更新 events 表的 RLS 政策（如果表存在）
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'events') THEN
        DROP POLICY IF EXISTS "管理員可以管理活動" ON events;
        
        CREATE POLICY "管理員可以管理活動" ON events
            FOR ALL
            USING (is_admin(auth.uid()));
    END IF;
END $$;

-- 8.4 更新 music 表的 RLS 政策（如果表存在）
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'music') THEN
        DROP POLICY IF EXISTS "管理員可以管理音樂" ON music;
        
        CREATE POLICY "管理員可以管理音樂" ON music
            FOR ALL
            USING (is_admin(auth.uid()));
    END IF;
END $$;

-- =====================================================
-- 步驟 9：創建管理員管理視圖（可選）
-- =====================================================
-- 為了方便查看和管理管理員，創建一個視圖

CREATE OR REPLACE VIEW admin_users_view AS
SELECT 
    id,
    email,
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name,
    created_at,
    last_sign_in_at,
    email_confirmed_at
FROM auth.users
WHERE raw_user_meta_data->>'role' IN ('admin', 'super_admin')
ORDER BY created_at DESC;

-- 設定視圖權限（僅超級管理員可查看）
GRANT SELECT ON admin_users_view TO authenticated;

CREATE POLICY "超級管理員可以查看管理員列表" ON admin_users_view
    FOR SELECT
    USING (is_super_admin(auth.uid()));

-- =====================================================
-- 步驟 10：更新審計日誌記錄方式
-- =====================================================
-- 創建新的審計日誌記錄函數（使用 Supabase Auth）

CREATE OR REPLACE FUNCTION log_admin_action(
    p_action TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_changes JSONB DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_user_email TEXT;
    v_user_role TEXT;
    v_log_id UUID;
BEGIN
    -- 獲取當前用戶資訊
    v_user_id := auth.uid();
    
    SELECT email, raw_user_meta_data->>'role'
    INTO v_user_email, v_user_role
    FROM auth.users
    WHERE id = v_user_id;
    
    -- 插入審計日誌
    INSERT INTO audit_logs (
        auth_user_id,
        admin_username,
        admin_role,
        action,
        resource_type,
        resource_id,
        description,
        changes,
        ip_address,
        user_agent
    ) VALUES (
        v_user_id,
        v_user_email,
        v_user_role,
        p_action,
        p_resource_type,
        p_resource_id,
        p_description,
        p_changes,
        p_ip_address,
        p_user_agent
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 驗證與測試
-- =====================================================

-- 測試 1：檢查管理員數量
SELECT COUNT(*) as admin_count 
FROM auth.users 
WHERE raw_user_meta_data->>'role' IN ('admin', 'super_admin');

-- 測試 2：檢查超級管理員
SELECT email, raw_user_meta_data->>'role' as role
FROM auth.users 
WHERE raw_user_meta_data->>'role' = 'super_admin';

-- 測試 3：測試輔助函數
-- 將 'your-user-id' 替換為實際的用戶 ID
-- SELECT is_admin('your-user-id');
-- SELECT is_super_admin('your-user-id');
-- SELECT * FROM get_admin_info('your-user-id');

-- 測試 4：查看管理員視圖
SELECT * FROM admin_users_view;

-- =====================================================
-- 清理建議
-- =====================================================

-- 在確認系統運作正常後（建議至少 30 天），執行以下清理：

-- 1. 刪除已棄用的 admins 表
-- DROP TABLE IF EXISTS admins_deprecated CASCADE;

-- 2. 刪除備份表（如果不再需要）
-- DROP TABLE IF EXISTS admins_backup;

-- =====================================================
-- 回滾計劃（萬一需要）
-- =====================================================

-- 如果遷移後發現問題，可以暫時恢復 admins 表：
-- ALTER TABLE admins_deprecated RENAME TO admins;

-- 並恢復舊的 RLS 政策（需要手動重新創建）

-- =====================================================
-- 完成檢查清單
-- =====================================================
/*
□ 步驟 1：已在 Supabase Auth 創建所有管理員帳號
□ 步驟 2：已驗證所有管理員可以正常登入
□ 步驟 3：已創建 admins 表備份
□ 步驟 4：已更新 audit_logs 表結構
□ 步驟 5：已檢查並處理外鍵依賴
□ 步驟 6：已重命名 admins 表為 admins_deprecated
□ 步驟 7：已創建輔助函數
□ 步驟 8：已更新所有 RLS 政策
□ 步驟 9：已創建管理員視圖
□ 步驟 10：已更新審計日誌函數
□ 前端登入邏輯已更新
□ 已進行完整測試
□ 系統運作正常至少 7-30 天
□ 已刪除 admins_deprecated 表
*/

-- =====================================================
-- 注意事項
-- =====================================================
/*
1. ⚠️ 此遷移是不可逆的操作，請確保已完整測試
2. ⚠️ 建議在低流量時段執行
3. ⚠️ 執行前請完整備份資料庫
4. ✅ 遷移後密碼將使用 Supabase 的加密機制
5. ✅ 可以使用 Supabase 內建的密碼重設功能
6. ✅ 支援 MFA、OAuth 等進階認證功能
*/
