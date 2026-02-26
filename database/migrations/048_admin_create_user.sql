-- ============================================
-- 超級管理員手動新增全新用戶
-- ============================================
-- RPC admin_create_user：
--   僅超管可呼叫，直接在 auth.users 建立新帳號
--   並自動確認 Email（不需要玩家收信確認）
-- 執行位置：Supabase Dashboard → SQL Editor
-- ============================================

CREATE OR REPLACE FUNCTION public.admin_create_user(
    user_email      text,
    user_password   text,
    display_name    text    DEFAULT NULL,
    user_role       text    DEFAULT NULL,
    game_master     text    DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    new_id      uuid;
    meta        jsonb;
BEGIN
    -- 僅超管可呼叫
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Only super admins can create users';
    END IF;

    -- 檢查 Email 是否已存在
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(trim(user_email))) THEN
        RAISE EXCEPTION 'Email 已被使用：%', user_email;
    END IF;

    new_id := gen_random_uuid();

    meta := jsonb_build_object(
        'display_name', COALESCE(display_name, ''),
        'role',         COALESCE(user_role, ''),
        'game_master',  COALESCE(game_master, '')
    );

    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        new_id,
        'authenticated',
        'authenticated',
        lower(trim(user_email)),
        crypt(user_password, gen_salt('bf')),
        now(),                                          -- 直接標記 Email 已驗證
        '{"provider":"email","providers":["email"]}'::jsonb,
        meta,
        now(),
        now(),
        '',
        ''
    );

    -- 同時建立 identity 記錄（Supabase auth 需要）
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at,
        provider_id
    ) VALUES (
        gen_random_uuid(),
        new_id,
        jsonb_build_object('sub', new_id::text, 'email', lower(trim(user_email))),
        'email',
        now(),
        now(),
        now(),
        lower(trim(user_email))
    );

    RETURN json_build_object(
        'id',    new_id,
        'email', lower(trim(user_email))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_user(text, text, text, text, text) TO authenticated;
