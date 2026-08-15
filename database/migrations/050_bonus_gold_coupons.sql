-- =====================================================
-- 蘇打石器：加送金幣券
-- 功能：儲值完成自動發券；下次儲值輸入代碼加送金幣
-- 執行：Supabase Dashboard → SQL Editor → 貼上整份執行
-- =====================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. 發券門檻（後台可調整）
CREATE TABLE IF NOT EXISTS public.bonus_coupon_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    min_recharge_amount INTEGER NOT NULL CHECK (min_recharge_amount >= 100),
    bonus_gold BIGINT NOT NULL CHECK (bonus_gold > 0),
    min_next_recharge INTEGER NOT NULL CHECK (min_next_recharge >= 100),
    validity_days INTEGER NOT NULL DEFAULT 30 CHECK (validity_days BETWEEN 1 AND 365),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 玩家持有的個人金幣券
CREATE TABLE IF NOT EXISTS public.bonus_coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rule_id UUID REFERENCES public.bonus_coupon_rules(id) ON DELETE SET NULL,
    bonus_gold BIGINT NOT NULL CHECK (bonus_gold > 0),
    min_recharge_amount INTEGER NOT NULL CHECK (min_recharge_amount >= 100),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'reserved', 'redeemed', 'revoked')),
    issued_donation_id UUID UNIQUE REFERENCES public.donations(id) ON DELETE SET NULL,
    reserved_donation_id UUID UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    redeemed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT bonus_coupons_reserved_donation_id_fkey
        FOREIGN KEY (reserved_donation_id)
        REFERENCES public.donations(id)
        ON DELETE SET NULL
        DEFERRABLE INITIALLY DEFERRED
);

-- 3. 訂單記錄使用的券與加送金幣（由資料庫驗證後寫入）
ALTER TABLE public.donations
    ADD COLUMN IF NOT EXISTS coupon_id UUID REFERENCES public.bonus_coupons(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS coupon_code TEXT,
    ADD COLUMN IF NOT EXISTS coupon_bonus_gold BIGINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_bonus_coupon_rules_active_threshold
    ON public.bonus_coupon_rules(is_active, min_recharge_amount DESC);
CREATE INDEX IF NOT EXISTS idx_bonus_coupons_user_status
    ON public.bonus_coupons(user_id, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_bonus_coupons_code_upper
    ON public.bonus_coupons(UPPER(code));
CREATE INDEX IF NOT EXISTS idx_donations_coupon_id
    ON public.donations(coupon_id);

-- 4. 預設門檻：採最高符合門檻，每筆完成訂單只發一張
INSERT INTO public.bonus_coupon_rules
    (name, min_recharge_amount, bonus_gold, min_next_recharge, validity_days, sort_order)
VALUES
    ('滿 500 回饋券',    500,    3000,   500, 30, 10),
    ('滿 1000 回饋券',  1000,    8000,  1000, 30, 20),
    ('滿 3000 回饋券',  3000,   30000,  3000, 30, 30),
    ('滿 5000 回饋券',  5000,   60000,  5000, 30, 40),
    ('滿 10000 回饋券',10000,  150000, 10000, 30, 50)
ON CONFLICT (name) DO NOTHING;

-- 5. 產生難以猜測、不可重複的代碼
CREATE OR REPLACE FUNCTION public.generate_bonus_coupon_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    candidate TEXT;
BEGIN
    LOOP
        candidate := 'SODA-' || UPPER(SUBSTRING(ENCODE(gen_random_bytes(6), 'hex') FROM 1 FOR 4))
                     || '-' || UPPER(SUBSTRING(ENCODE(gen_random_bytes(6), 'hex') FROM 5 FOR 4));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.bonus_coupons WHERE code = candidate
        );
    END LOOP;
    RETURN candidate;
END;
$$;

-- 6. 建立訂單時鎖定並驗證個人券，避免同一張券重複下單
CREATE OR REPLACE FUNCTION public.prepare_donation_bonus_coupon()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    coupon_row public.bonus_coupons%ROWTYPE;
BEGIN
    NEW.coupon_code := NULLIF(UPPER(TRIM(COALESCE(NEW.coupon_code, ''))), '');
    NEW.coupon_id := NULL;
    NEW.coupon_bonus_gold := 0;

    IF NEW.coupon_code IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO coupon_row
    FROM public.bonus_coupons
    WHERE UPPER(code) = NEW.coupon_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '找不到此金幣券代碼';
    END IF;
    IF coupon_row.user_id <> NEW.user_id THEN
        RAISE EXCEPTION '此金幣券不屬於目前會員';
    END IF;
    IF coupon_row.status <> 'active' THEN
        RAISE EXCEPTION '此金幣券已使用或已被其他訂單保留';
    END IF;
    IF coupon_row.expires_at <= NOW() THEN
        RAISE EXCEPTION '此金幣券已過期';
    END IF;
    IF NEW.amount < coupon_row.min_recharge_amount THEN
        RAISE EXCEPTION '本次儲值未達金幣券最低門檻 NT$ %', coupon_row.min_recharge_amount;
    END IF;

    NEW.coupon_id := coupon_row.id;
    NEW.coupon_code := coupon_row.code;
    NEW.coupon_bonus_gold := coupon_row.bonus_gold;

    UPDATE public.bonus_coupons
    SET status = 'reserved',
        reserved_donation_id = NEW.id,
        updated_at = NOW()
    WHERE id = coupon_row.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_prepare_donation_bonus_coupon ON public.donations;
CREATE TRIGGER trigger_prepare_donation_bonus_coupon
BEFORE INSERT ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.prepare_donation_bonus_coupon();

-- 7. 訂單完成：核銷舊券＋依本次金額自動發新券；取消：退回尚未核銷的券
CREATE OR REPLACE FUNCTION public.finalize_donation_bonus_coupon()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    matched_rule public.bonus_coupon_rules%ROWTYPE;
BEGIN
    IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
        IF NEW.coupon_id IS NOT NULL THEN
            UPDATE public.bonus_coupons
            SET status = 'redeemed',
                redeemed_at = NOW(),
                updated_at = NOW()
            WHERE id = NEW.coupon_id
              AND reserved_donation_id = NEW.id
              AND status = 'reserved';
        END IF;

        IF NEW.user_id IS NOT NULL THEN
            SELECT * INTO matched_rule
            FROM public.bonus_coupon_rules
            WHERE is_active = TRUE
              AND NEW.amount >= min_recharge_amount
            ORDER BY min_recharge_amount DESC, sort_order DESC
            LIMIT 1;

            IF FOUND THEN
                INSERT INTO public.bonus_coupons (
                    code, user_id, rule_id, bonus_gold, min_recharge_amount,
                    issued_donation_id, expires_at
                ) VALUES (
                    public.generate_bonus_coupon_code(), NEW.user_id, matched_rule.id,
                    matched_rule.bonus_gold, matched_rule.min_next_recharge,
                    NEW.id, NOW() + MAKE_INTERVAL(days => matched_rule.validity_days)
                )
                ON CONFLICT (issued_donation_id) DO NOTHING;
            END IF;
        END IF;
    ELSIF NEW.status = 'cancelled'
          AND OLD.status IS DISTINCT FROM 'completed'
          AND NEW.coupon_id IS NOT NULL THEN
        UPDATE public.bonus_coupons
        SET status = 'active',
            reserved_donation_id = NULL,
            updated_at = NOW()
        WHERE id = NEW.coupon_id
          AND reserved_donation_id = NEW.id
          AND status = 'reserved'
          AND expires_at > NOW();
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_finalize_donation_bonus_coupon ON public.donations;
CREATE TRIGGER trigger_finalize_donation_bonus_coupon
AFTER UPDATE OF status ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.finalize_donation_bonus_coupon();

-- 8. RLS：玩家只能看自己的券；發券／核銷只能由觸發器或管理員執行
ALTER TABLE public.bonus_coupon_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bonus_coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players can read active coupon rules" ON public.bonus_coupon_rules;
CREATE POLICY "Players can read active coupon rules"
ON public.bonus_coupon_rules FOR SELECT
TO authenticated
USING (is_active = TRUE OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage coupon rules" ON public.bonus_coupon_rules;
CREATE POLICY "Admins can manage coupon rules"
ON public.bonus_coupon_rules FOR ALL
TO authenticated
USING (public.is_admin(auth.uid()))
WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Players can read own bonus coupons" ON public.bonus_coupons;
CREATE POLICY "Players can read own bonus coupons"
ON public.bonus_coupons FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage bonus coupons" ON public.bonus_coupons;
CREATE POLICY "Admins can manage bonus coupons"
ON public.bonus_coupons FOR ALL
TO authenticated
USING (public.is_admin(auth.uid()))
WITH CHECK (public.is_admin(auth.uid()));

GRANT SELECT ON public.bonus_coupon_rules TO authenticated;
GRANT SELECT ON public.bonus_coupons TO authenticated;
GRANT ALL ON public.bonus_coupon_rules TO authenticated;
GRANT ALL ON public.bonus_coupons TO authenticated;

COMMENT ON TABLE public.bonus_coupon_rules IS '儲值完成後自動發送加送金幣券的門檻規則';
COMMENT ON TABLE public.bonus_coupons IS '玩家個人金幣券；可選券或輸入代碼於下次儲值使用';
COMMENT ON COLUMN public.donations.coupon_bonus_gold IS '此訂單使用金幣券所加送的金幣數量';
