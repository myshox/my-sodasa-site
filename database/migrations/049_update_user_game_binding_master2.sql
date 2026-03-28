-- ============================================
-- 049：遊戲綁定 RPC 支援「第二主帳號」game_master2
-- ============================================
-- 問題：前端呼叫 update_user_game_binding 時帶入 new_game_master2，
--       但 047 僅定義 (uuid, text, jsonb)，PostgREST 找不到對應函式而失敗。
-- 做法：
--   1. 改為四參數 (uuid, text, text, jsonb)，寫入 raw_user_meta_data.game_master2
--   2. get_all_users 回傳欄位新增 game_master2（後台編輯表單需讀取）
-- 執行：Supabase Dashboard → SQL Editor → 貼上整段執行
-- ============================================

-- 舊版三參數（若存在則移除）
DROP FUNCTION IF EXISTS public.update_user_game_binding(uuid, text, jsonb);
-- 若曾手動建立四參數同名函式，先卸載再建
DROP FUNCTION IF EXISTS public.update_user_game_binding(uuid, text, text, jsonb);

CREATE OR REPLACE FUNCTION public.update_user_game_binding(
    target_user_id   uuid,
    new_game_master  text    DEFAULT NULL,
    new_game_master2 text    DEFAULT NULL,
    new_game_accounts jsonb  DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    meta jsonb;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid()
        AND auth.users.raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can update game binding';
    END IF;

    SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) INTO meta
    FROM auth.users WHERE id = target_user_id;

    IF meta IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- NULL = 不變更（相容舊呼叫）；空字串 = 清除該欄位
    IF new_game_master IS NOT NULL THEN
        IF length(trim(new_game_master)) = 0 THEN
            meta := meta - 'game_master';
        ELSE
            meta := jsonb_set(meta, '{game_master}', to_jsonb(trim(new_game_master)), true);
        END IF;
    END IF;

    IF new_game_master2 IS NOT NULL THEN
        IF length(trim(new_game_master2)) = 0 THEN
            meta := meta - 'game_master2';
        ELSE
            meta := jsonb_set(meta, '{game_master2}', to_jsonb(trim(new_game_master2)), true);
        END IF;
    END IF;

    IF new_game_accounts IS NOT NULL THEN
        meta := jsonb_set(meta, '{game_accounts}', new_game_accounts, true);
    END IF;

    UPDATE auth.users
    SET raw_user_meta_data = meta
    WHERE id = target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_game_binding(uuid, text, text, jsonb) TO authenticated;


-- ----- get_all_users：新增 game_master2 -----

DROP FUNCTION IF EXISTS public.get_all_users();

CREATE OR REPLACE FUNCTION public.get_all_users()
RETURNS TABLE (
    id                  uuid,
    email               character varying,
    created_at          timestamptz,
    role                text,
    total_amount        integer,
    total_coins         integer,
    display_name        text,
    game_special_id_1   text,
    game_special_id_2   text,
    game_special_id_3   text,
    game_special_id_4   text,
    game_special_id_5   text,
    game_master         text,
    game_master2        text,
    game_accounts       jsonb
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
        u.raw_user_meta_data->>'role'                               AS role,
        COALESCE(SUM(d.amount), 0)::integer                        AS total_amount,
        COALESCE(SUM(d.coins),  0)::integer                        AS total_coins,
        (u.raw_user_meta_data->>'display_name')::text              AS display_name,
        (u.raw_user_meta_data->'game_special_ids'->>0)::text       AS game_special_id_1,
        (u.raw_user_meta_data->'game_special_ids'->>1)::text       AS game_special_id_2,
        (u.raw_user_meta_data->'game_special_ids'->>2)::text       AS game_special_id_3,
        (u.raw_user_meta_data->'game_special_ids'->>3)::text       AS game_special_id_4,
        (u.raw_user_meta_data->'game_special_ids'->>4)::text       AS game_special_id_5,
        (u.raw_user_meta_data->>'game_master')::text               AS game_master,
        (u.raw_user_meta_data->>'game_master2')::text              AS game_master2,
        (u.raw_user_meta_data->'game_accounts')                    AS game_accounts
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
