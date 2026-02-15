-- ============================================
-- 修復 Function Search Path Mutable 安全警告
-- ============================================
-- 為所有函數加上 SET search_path = public，防止 search_path 注入
-- 執行：Supabase Dashboard → SQL Editor
-- ============================================

ALTER FUNCTION public.set_publish_date() SET search_path = public;
ALTER FUNCTION public.increment_guide_views(UUID) SET search_path = public;
ALTER FUNCTION public.generate_order_number() SET search_path = public;
ALTER FUNCTION public.set_order_number() SET search_path = public;
ALTER FUNCTION public.is_admin(UUID) SET search_path = public;
ALTER FUNCTION public.is_super_admin(UUID) SET search_path = public;
ALTER FUNCTION public.get_admin_info(UUID) SET search_path = public;
ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
ALTER FUNCTION public.upsert_ip_location(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL, DECIMAL, TEXT, TEXT, TEXT, JSONB) SET search_path = public;
ALTER FUNCTION public.log_admin_action(TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT) SET search_path = public;
-- 若 030_guides_rls_use_jwt_metadata 已執行，則有此函數
DO $$ BEGIN
  ALTER FUNCTION public.is_guide_admin() SET search_path = public;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;
