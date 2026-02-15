-- ============================================
-- 修復：註冊用戶累計儲值與充值紀錄同步
-- ============================================
-- 問題：get_all_users 原先用 u.email = d.email 關聯 donations，
--       若 email 大小寫或格式不一致，會導致累計金額不正確或不同步。
-- 做法：改為以 user_id 為主關聯（與儲值時寫入的 user_id 一致），
--       並保留以 email 的相容處理（舊資料或 user_id 為 NULL 時）。
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

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
    -- 僅允許超級管理員呼叫
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can view users';
    END IF;

    -- 以 user_id 關聯為主，確保「客人充值紀錄」會同步到「註冊用戶的累積金額」
    -- 相容：user_id 為 NULL 的舊資料改以 email 比對（不區分大小寫、去除空白）
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.created_at,
        u.raw_user_meta_data->>'role' as role,
        COALESCE(SUM(d.amount), 0)::integer as total_amount,
        COALESCE(SUM(d.coins), 0)::integer as total_coins
    FROM auth.users u
    LEFT JOIN donations d ON (
        d.user_id = u.id
        OR (
            d.user_id IS NULL
            AND LOWER(TRIM(COALESCE(d.email, ''))) = LOWER(TRIM(COALESCE(u.email::text, '')))
        )
    )
    GROUP BY u.id, u.email, u.created_at, u.raw_user_meta_data
    ORDER BY u.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_users() TO authenticated;

-- ============================================
-- 驗證建議（執行完後可選跑）
-- ============================================
-- 查看某用戶的 donations 筆數與加總（替換成實際 user id）：
-- SELECT user_id, email, COUNT(*), SUM(amount), SUM(coins)
-- FROM donations
-- WHERE user_id = '這裡填用戶 UUID'
-- GROUP BY user_id, email;
--
-- 比對 get_all_users 回傳的 total_amount / total_coins 是否一致。
