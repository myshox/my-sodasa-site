-- =====================================================
-- Supabase Auth 完整遷移方案（修復版）
-- 目的：移除 admins 表，統一使用 Supabase Auth
-- 修復：解決 music/events 表可能不存在的問題
-- =====================================================

-- ⚠️ 重要提醒：
-- 1. 請先在 Supabase Dashboard 的 Authentication 創建管理員帳號
-- 2. 設定 user_metadata: {"role": "super_admin"}
-- 3. 執行此腳本前請先備份資料庫
-- 4. 建議在低流量時段執行

-- =====================================================
-- 步驟 1：備份 admins 表（以防萬一）
-- =====================================================
CREATE TABLE IF NOT EXISTS admins_backup AS
SELECT * FROM admins;

-- 驗證備份
SELECT COUNT(*) as backup_count FROM admins_backup;

-- =====================================================
-- 步驟 2：更新 audit_logs 表結構
-- =====================================================
ALTER TABLE audit_logs 
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- =====================================================
-- 步驟 3：創建輔助函數
-- =====================================================

-- 3.1 檢查用戶是否為管理員
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

-- 3.2 檢查用戶是否為超級管理員
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

-- 3.3 獲取管理員資訊
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
-- 步驟 4：更新 RLS 政策
-- =====================================================

-- 4.1 更新 donations 表的 RLS 政策
DROP POLICY IF EXISTS "管理員可以查看所有贊助記錄" ON donations;
DROP POLICY IF EXISTS "管理員可以更新贊助記錄" ON donations;
DROP POLICY IF EXISTS "管理員可以刪除贊助記錄" ON donations;

CREATE POLICY "管理員可以查看所有贊助記錄" ON donations
    FOR SELECT
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以更新贊助記錄" ON donations
    FOR UPDATE
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以刪除贊助記錄" ON donations
    FOR DELETE
    USING (is_admin(auth.uid()));

-- 4.2 更新 audit_logs 表的 RLS 政策
DROP POLICY IF EXISTS "管理員可以查看審計日誌" ON audit_logs;
DROP POLICY IF EXISTS "管理員可以寫入審計日誌" ON audit_logs;

CREATE POLICY "管理員可以查看審計日誌" ON audit_logs
    FOR SELECT
    USING (is_admin(auth.uid()));

CREATE POLICY "管理員可以寫入審計日誌" ON audit_logs
    FOR INSERT
    WITH CHECK (is_admin(auth.uid()));

-- 4.3 更新 events 表的 RLS 政策（如果表存在）
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'events') THEN
        EXECUTE 'DROP POLICY IF EXISTS "管理員可以管理活動" ON events';
        EXECUTE 'CREATE POLICY "管理員可以管理活動" ON events FOR ALL USING (is_admin(auth.uid()))';
    END IF;
END $$;

-- 4.4 更新 music 表的 RLS 政策（如果表存在）
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'music') THEN
        EXECUTE 'DROP POLICY IF EXISTS "管理員可以管理音樂" ON music';
        EXECUTE 'CREATE POLICY "管理員可以管理音樂" ON music FOR ALL USING (is_admin(auth.uid()))';
    END IF;
END $$;

-- =====================================================
-- 步驟 5：創建審計日誌記錄函數
-- =====================================================
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
-- 步驟 6：安全刪除/重命名 admins 表
-- =====================================================
-- ⚠️ 警告：執行此步驟前請確認：
-- 1. 所有管理員已成功遷移到 Supabase Auth
-- 2. 已創建備份（admins_backup 表）
-- 3. 前端登入邏輯已更新
-- 4. 已經測試過新的登入流程

-- 檢查是否有外鍵依賴
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

-- 重命名表而不是立即刪除（建議觀察 7-30 天後再刪除）
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admins') THEN
        ALTER TABLE admins RENAME TO admins_deprecated;
    END IF;
END $$;

-- 可以在確認系統運作正常後（例如 7-30 天後），再執行：
-- DROP TABLE IF EXISTS admins_deprecated CASCADE;

-- =====================================================
-- 驗證與測試
-- =====================================================

-- 測試 1：檢查管理員數量
SELECT COUNT(*) as admin_count 
FROM auth.users 
WHERE raw_user_meta_data->>'role' IN ('admin', 'super_admin');

-- 測試 2：檢查超級管理員
SELECT 
    email, 
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name,
    created_at
FROM auth.users 
WHERE raw_user_meta_data->>'role' = 'super_admin';

-- 測試 3：檢查備份表
SELECT COUNT(*) as backup_count FROM admins_backup;

-- 測試 4：檢查輔助函數
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN ('is_admin', 'is_super_admin', 'get_admin_info', 'log_admin_action');

-- =====================================================
-- 完成訊息
-- =====================================================
DO $$ 
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ Supabase Auth 遷移完成！';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '請確認：';
    RAISE NOTICE '1. 管理員帳號已在 Supabase Auth 創建';
    RAISE NOTICE '2. 前端登入功能測試正常';
    RAISE NOTICE '3. 所有後台功能運作正常';
    RAISE NOTICE '4. admins 表已重命名為 admins_deprecated';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ 建議觀察 7-30 天後再刪除 admins_deprecated 表';
    RAISE NOTICE '==============================================';
END $$;
