-- ============================================
-- 五個角色各自一個特殊編號（取代單一 game_special_id）
-- ============================================
-- 1. update_user_profile 改為接受 game_special_ids (jsonb 陣列，長度 5)
-- 2. get_all_users 改為回傳 game_special_id_1 .. game_special_id_5
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

DROP FUNCTION IF EXISTS public.update_user_profile(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.update_user_profile(
    target_user_id uuid,
    display_name text DEFAULT NULL,
    role text DEFAULT NULL,
    game_special_ids jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    meta jsonb;
    arr jsonb;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can update user profile';
    END IF;

    SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) INTO meta
    FROM auth.users
    WHERE id = target_user_id;

    IF meta IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    IF display_name IS NOT NULL THEN
        meta := jsonb_set(meta, '{display_name}', to_jsonb(display_name::text), true);
    END IF;
    IF role IS NOT NULL THEN
        meta := jsonb_set(meta, '{role}', to_jsonb(role::text), true);
    END IF;
    IF game_special_ids IS NOT NULL THEN
        -- 確保為長度 5 的陣列，不足補空字串、多於截斷
        arr := jsonb_build_array(
            COALESCE(game_special_ids->>0, ''),
            COALESCE(game_special_ids->>1, ''),
            COALESCE(game_special_ids->>2, ''),
            COALESCE(game_special_ids->>3, ''),
            COALESCE(game_special_ids->>4, '')
        );
        meta := jsonb_set(meta, '{game_special_ids}', arr, true);
    END IF;

    UPDATE auth.users
    SET raw_user_meta_data = meta
    WHERE id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_profile(uuid, text, text, jsonb) TO authenticated;

-- 擴充 get_all_users：回傳 5 個角色特殊編號
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
    game_special_id_1 text,
    game_special_id_2 text,
    game_special_id_3 text,
    game_special_id_4 text,
    game_special_id_5 text
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
        (u.raw_user_meta_data->'game_special_ids'->>0)::text as game_special_id_1,
        (u.raw_user_meta_data->'game_special_ids'->>1)::text as game_special_id_2,
        (u.raw_user_meta_data->'game_special_ids'->>2)::text as game_special_id_3,
        (u.raw_user_meta_data->'game_special_ids'->>3)::text as game_special_id_4,
        (u.raw_user_meta_data->'game_special_ids'->>4)::text as game_special_id_5
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
