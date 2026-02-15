-- 修改 get_all_users 函數，新增累計儲值金額
DROP FUNCTION IF EXISTS public.get_all_users();

CREATE OR REPLACE FUNCTION public.get_all_users()
RETURNS TABLE (
    id uuid,
    email character varying,
    created_at timestamptz,
    role text,
    total_amount integer,
    total_coins integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 檢查調用者是否為超管
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can view users';
    END IF;

    -- 返回用戶列表（包含累計儲值金額和金幣）
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.created_at,
        u.raw_user_meta_data->>'role' as role,
        COALESCE(SUM(d.amount), 0)::integer as total_amount,
        COALESCE(SUM(d.coins), 0)::integer as total_coins
    FROM auth.users u
    LEFT JOIN donations d ON u.email = d.email
    GROUP BY u.id, u.email, u.created_at, u.raw_user_meta_data
    ORDER BY u.created_at DESC;
END;
$$;

-- 授予執行權限
GRANT EXECUTE ON FUNCTION public.get_all_users() TO authenticated;
