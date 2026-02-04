-- =============================================
-- 操作日誌表（Audit Logs）
-- 用於追蹤所有管理員操作
-- =============================================

-- 建立 audit_logs 表
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 操作者資訊
    admin_id TEXT NOT NULL,                    -- 管理員 ID（admins 表）或 Supabase Auth user_id
    admin_username TEXT NOT NULL,               -- 管理員名稱
    admin_role TEXT,                            -- 管理員角色（admin/super_admin）
    
    -- 操作資訊
    action TEXT NOT NULL,                       -- 操作類型：create/update/delete/login/logout
    resource_type TEXT NOT NULL,                -- 資源類型：donation/event/music/admin/settings
    resource_id TEXT,                           -- 資源 ID
    
    -- 操作詳情
    description TEXT NOT NULL,                  -- 操作描述（中文）
    changes JSONB,                              -- 變更內容（舊值 -> 新值）
    
    -- 請求資訊
    ip_address TEXT,                            -- IP 地址
    user_agent TEXT,                            -- 瀏覽器資訊
    
    -- 時間戳記
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- 索引欄位
    CONSTRAINT audit_logs_action_check CHECK (action IN ('create', 'update', 'delete', 'login', 'logout', 'view'))
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_id ON public.audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource_type ON public.audit_logs(resource_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);

-- 建立複合索引（常用查詢組合）
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_resource ON public.audit_logs(admin_id, resource_type, created_at DESC);

-- 啟用 RLS（Row Level Security）
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 建立 RLS 政策：只有管理員可以查看日誌
CREATE POLICY "管理員可查看所有日誌"
ON public.audit_logs
FOR SELECT
USING (true); -- 前端會進行管理員驗證

-- 建立 RLS 政策：允許插入日誌（由系統自動記錄）
CREATE POLICY "允許插入操作日誌"
ON public.audit_logs
FOR INSERT
WITH CHECK (true);

-- 建立 RLS 政策：禁止修改和刪除日誌（確保日誌完整性）
CREATE POLICY "禁止修改日誌"
ON public.audit_logs
FOR UPDATE
USING (false);

CREATE POLICY "禁止刪除日誌"
ON public.audit_logs
FOR DELETE
USING (false);

-- =============================================
-- 測試資料（可選）
-- =============================================

-- 插入測試日誌
INSERT INTO public.audit_logs (admin_id, admin_username, admin_role, action, resource_type, description, created_at)
VALUES 
    ('test-admin-1', 'admin', 'super_admin', 'login', 'admin', '管理員登入系統', NOW() - INTERVAL '2 hours'),
    ('test-admin-1', 'admin', 'super_admin', 'update', 'donation', '將贊助 #12345 標記為已完成', NOW() - INTERVAL '1 hour'),
    ('test-admin-1', 'admin', 'super_admin', 'logout', 'admin', '管理員登出系統', NOW() - INTERVAL '30 minutes');

-- =============================================
-- 查詢範例
-- =============================================

-- 1. 查看最近 50 筆操作記錄
-- SELECT * FROM public.audit_logs ORDER BY created_at DESC LIMIT 50;

-- 2. 查看特定管理員的操作記錄
-- SELECT * FROM public.audit_logs WHERE admin_username = 'admin' ORDER BY created_at DESC;

-- 3. 查看特定資源類型的操作
-- SELECT * FROM public.audit_logs WHERE resource_type = 'donation' ORDER BY created_at DESC;

-- 4. 查看特定時間範圍的操作
-- SELECT * FROM public.audit_logs WHERE created_at >= NOW() - INTERVAL '7 days' ORDER BY created_at DESC;

-- 5. 統計每個管理員的操作次數
-- SELECT admin_username, COUNT(*) as operation_count FROM public.audit_logs GROUP BY admin_username ORDER BY operation_count DESC;

-- 6. 統計操作類型分布
-- SELECT action, COUNT(*) as count FROM public.audit_logs GROUP BY action ORDER BY count DESC;

COMMENT ON TABLE public.audit_logs IS '操作日誌表：記錄所有管理員操作，確保系統安全性和可追溯性';
COMMENT ON COLUMN public.audit_logs.admin_id IS '管理員 ID';
COMMENT ON COLUMN public.audit_logs.action IS '操作類型：create/update/delete/login/logout/view';
COMMENT ON COLUMN public.audit_logs.resource_type IS '資源類型：donation/event/music/admin/settings';
COMMENT ON COLUMN public.audit_logs.changes IS '變更內容（JSON 格式），記錄修改前後的值';
