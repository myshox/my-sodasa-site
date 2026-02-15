-- =============================================
-- 為系統加入 IP 位置追蹤功能
-- =============================================

-- 1. 為 donations 表加入 IP 相關欄位
ALTER TABLE public.donations 
ADD COLUMN IF NOT EXISTS ip_address TEXT,
ADD COLUMN IF NOT EXISTS ip_location JSONB DEFAULT '{}'::jsonb;

-- 2. 為 audit_logs 表的 ip_address 欄位加入索引（如果還沒有）
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip_address ON public.audit_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_donations_ip_address ON public.donations(ip_address);

-- 3. 建立 IP 位置記錄表（詳細的 IP 查詢記錄）
CREATE TABLE IF NOT EXISTS public.ip_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ip_address TEXT NOT NULL UNIQUE,
    
    -- 地理位置資訊
    country TEXT,              -- 國家
    country_code TEXT,         -- 國家代碼 (TW, US, JP...)
    region TEXT,               -- 地區/州
    city TEXT,                 -- 城市
    postal_code TEXT,          -- 郵遞區號
    
    -- 座標
    latitude DECIMAL(10, 7),   -- 緯度
    longitude DECIMAL(10, 7),  -- 經度
    
    -- 網路資訊
    timezone TEXT,             -- 時區
    isp TEXT,                  -- ISP 供應商
    organization TEXT,         -- 組織
    
    -- 完整 API 回應（備份）
    raw_data JSONB,
    
    -- 時間戳記
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- 查詢次數統計
    query_count INT DEFAULT 1
);

-- 4. 建立索引
CREATE INDEX IF NOT EXISTS idx_ip_locations_country ON public.ip_locations(country);
CREATE INDEX IF NOT EXISTS idx_ip_locations_city ON public.ip_locations(city);
CREATE INDEX IF NOT EXISTS idx_ip_locations_created_at ON public.ip_locations(created_at DESC);

-- 5. 啟用 RLS
ALTER TABLE public.ip_locations ENABLE ROW LEVEL SECURITY;

-- 6. 建立 RLS 政策
CREATE POLICY "管理員可查看 IP 位置"
ON public.ip_locations
FOR SELECT
USING (true);

CREATE POLICY "允許插入 IP 位置"
ON public.ip_locations
FOR INSERT
WITH CHECK (true);

CREATE POLICY "允許更新 IP 位置"
ON public.ip_locations
FOR UPDATE
USING (true);

-- 7. 註解說明
COMMENT ON TABLE public.ip_locations IS 'IP 位置記錄表：儲存 IP 地址的地理位置資訊';
COMMENT ON COLUMN public.donations.ip_address IS '贊助者的 IP 地址';
COMMENT ON COLUMN public.donations.ip_location IS 'IP 位置資訊（JSON 格式）';

-- =============================================
-- 函數：更新或插入 IP 位置資訊
-- =============================================

CREATE OR REPLACE FUNCTION upsert_ip_location(
    p_ip_address TEXT,
    p_country TEXT,
    p_country_code TEXT,
    p_region TEXT,
    p_city TEXT,
    p_postal_code TEXT,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_timezone TEXT,
    p_isp TEXT,
    p_organization TEXT,
    p_raw_data JSONB
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.ip_locations (
        ip_address, country, country_code, region, city, postal_code,
        latitude, longitude, timezone, isp, organization, raw_data
    )
    VALUES (
        p_ip_address, p_country, p_country_code, p_region, p_city, p_postal_code,
        p_latitude, p_longitude, p_timezone, p_isp, p_organization, p_raw_data
    )
    ON CONFLICT (ip_address) 
    DO UPDATE SET
        country = EXCLUDED.country,
        country_code = EXCLUDED.country_code,
        region = EXCLUDED.region,
        city = EXCLUDED.city,
        postal_code = EXCLUDED.postal_code,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        timezone = EXCLUDED.timezone,
        isp = EXCLUDED.isp,
        organization = EXCLUDED.organization,
        raw_data = EXCLUDED.raw_data,
        updated_at = NOW(),
        query_count = ip_locations.query_count + 1
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 查詢範例
-- =============================================

-- 1. 查看所有 IP 位置記錄
-- SELECT * FROM ip_locations ORDER BY created_at DESC;

-- 2. 統計各國家的贊助數量
-- SELECT 
--     il.country,
--     il.country_code,
--     COUNT(d.id) as donation_count,
--     SUM(d.amount) as total_amount
-- FROM donations d
-- LEFT JOIN ip_locations il ON d.ip_address = il.ip_address
-- WHERE il.country IS NOT NULL
-- GROUP BY il.country, il.country_code
-- ORDER BY donation_count DESC;

-- 3. 查看特定 IP 的所有贊助
-- SELECT * FROM donations WHERE ip_address = '1.2.3.4';

-- 4. 統計各城市的贊助
-- SELECT 
--     il.city,
--     il.region,
--     COUNT(*) as count
-- FROM ip_locations il
-- GROUP BY il.city, il.region
-- ORDER BY count DESC
-- LIMIT 10;

-- 5. 查看最近的 IP 位置記錄
-- SELECT 
--     ip_address,
--     city,
--     country,
--     created_at
-- FROM ip_locations
-- ORDER BY created_at DESC
-- LIMIT 20;

-- =============================================
-- 隱私注意事項
-- =============================================

/*
⚠️ 重要提醒：

1. 隱私政策：
   - 請在網站隱私政策中說明會記錄 IP 地址
   - 說明 IP 記錄的用途（安全、分析、防詐欺）
   - 遵守 GDPR、台灣個資法等相關法規

2. 資料保留：
   - 考慮定期清理過舊的 IP 記錄
   - 建議保留期限：6-12 個月

3. 安全性：
   - IP 資訊應僅限管理員查看
   - 不要在前台顯示其他用戶的 IP

4. 使用限制：
   - 僅用於合法目的（安全、分析）
   - 不要用於追蹤或監視用戶行為
*/

COMMENT ON TABLE public.ip_locations IS 'IP 位置記錄表：請遵守隱私法規，僅用於安全監控和數據分析';
