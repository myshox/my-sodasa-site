-- ============================================
-- 註冊用戶：管理員可編輯資料、角色、遊戲特殊編號
-- ============================================
-- 1. 新增 RPC update_user_profile：僅超級管理員可呼叫，更新目標用戶的
--    raw_user_meta_data（display_name, role, game_special_id）。
-- 2. 擴充 get_all_users 回傳 display_name、game_special_id，供列表與編輯表單使用。
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

-- 僅在可更新 auth.users 的環境下建立（Supabase 專案內 postgres 通常具權限）
CREATE OR REPLACE FUNCTION public.update_user_profile(
    target_user_id uuid,
    display_name text DEFAULT NULL,
    role text DEFAULT NULL,
    game_special_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    meta jsonb;
BEGIN
    -- 僅允許超級管理員呼叫
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can update user profile';
    END IF;

    -- 讀取目標用戶現有 raw_user_meta_data，合併傳入欄位（僅非 NULL 的覆寫）
    SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) INTO meta
    FROM auth.users
    WHERE id = target_user_id;

    IF meta IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- 僅 NULL 不覆寫；空字串會寫入（可清空欄位）
    IF display_name IS NOT NULL THEN
        meta := jsonb_set(meta, '{display_name}', to_jsonb(display_name::text), true);
    END IF;
    IF role IS NOT NULL THEN
        meta := jsonb_set(meta, '{role}', to_jsonb(role::text), true);
    END IF;
    IF game_special_id IS NOT NULL THEN
        meta := jsonb_set(meta, '{game_special_id}', to_jsonb(game_special_id::text), true);
    END IF;
    -- 若前端要「清空」可傳空字串，此處以「NOT NULL」判斷，故傳 '' 會寫入空字串

    UPDATE auth.users
    SET raw_user_meta_data = meta
    WHERE id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_profile(uuid, text, text, text) TO authenticated;

-- 擴充 get_all_users：多回傳 display_name、game_special_id
DROP FUNCTION IF EXISTS public.get_all_users();

CREATE OR REPLACE FUNCTION public.get_all_users()
RETURNS TABLE (
    id uuid,
    email character varying,
    created_at timestamptz,
    role text,
    total_amount integer,
    total_coins integer,
    display_name text,
    game_special_id text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can view users';
    END IF;

    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.created_at,
        u.raw_user_meta_data->>'role' as role,
        COALESCE(SUM(d.amount), 0)::integer as total_amount,
        COALESCE(SUM(d.coins), 0)::integer as total_coins,
        (u.raw_user_meta_data->>'display_name')::text as display_name,
        (u.raw_user_meta_data->>'game_special_id')::text as game_special_id
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
