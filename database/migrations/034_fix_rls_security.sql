-- ============================================
-- 修復 Supabase Database Linter 安全問題
-- ============================================
-- 問題：donations 有 RLS 政策但 RLS 未啟用、admins_backup 未啟用 RLS 且含敏感欄位
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

-- 1. donations：啟用 RLS（政策已存在，只需啟用）
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;

-- 2. admins_backup：啟用 RLS 並禁止 API 存取（備份表含 password，不應透過 API 暴露）
ALTER TABLE public.admins_backup ENABLE ROW LEVEL SECURITY;

-- 禁止所有透過 PostgREST 的存取（anon、authenticated 無法讀寫）
-- service_role 仍可透過 Dashboard SQL 存取，利於緊急還原
DROP POLICY IF EXISTS "admins_backup_no_api_access" ON public.admins_backup;
CREATE POLICY "admins_backup_no_api_access"
  ON public.admins_backup
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- ============================================
-- 驗證
-- ============================================
-- SELECT relname, relrowsecurity
-- FROM pg_class
-- WHERE relname IN ('donations', 'admins_backup');
-- relrowsecurity 應皆為 true
