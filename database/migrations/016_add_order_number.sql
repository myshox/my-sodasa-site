-- 新增訂單編號欄位到 donations 表
ALTER TABLE donations 
ADD COLUMN IF NOT EXISTS order_number TEXT UNIQUE;

-- 添加註解
COMMENT ON COLUMN donations.order_number IS '唯一訂單編號，格式：SD+日期+流水號';

-- 創建索引以優化查詢效能
CREATE INDEX IF NOT EXISTS idx_donations_order_number ON donations(order_number);

-- 創建函數：生成唯一訂單編號
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    date_prefix TEXT;
    max_sequence INTEGER;
    new_order_number TEXT;
BEGIN
    -- 生成日期前綴（格式：SD20260201）
    date_prefix := 'SD' || TO_CHAR(NOW(), 'YYYYMMDD');
    
    -- 查詢今天最大的流水號
    SELECT COALESCE(
        MAX(
            CAST(
                SUBSTRING(order_number FROM LENGTH(date_prefix) + 2) 
                AS INTEGER
            )
        ), 
        0
    ) INTO max_sequence
    FROM donations
    WHERE order_number LIKE date_prefix || '-%';
    
    -- 生成新的訂單編號（流水號補零到3位）
    new_order_number := date_prefix || '-' || LPAD((max_sequence + 1)::TEXT, 3, '0');
    
    RETURN new_order_number;
END;
$$;

-- 創建 Trigger：自動為新記錄生成訂單編號
CREATE OR REPLACE FUNCTION set_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number := generate_order_number();
    END IF;
    RETURN NEW;
END;
$$;

-- 綁定 Trigger 到 donations 表
DROP TRIGGER IF EXISTS trigger_set_order_number ON donations;
CREATE TRIGGER trigger_set_order_number
    BEFORE INSERT ON donations
    FOR EACH ROW
    EXECUTE FUNCTION set_order_number();

-- 為現有記錄生成訂單編號（按 created_at 順序）
DO $$
DECLARE
    rec RECORD;
    counter INTEGER;
    last_date TEXT;
    date_prefix TEXT;
BEGIN
    last_date := '';
    counter := 0;
    
    FOR rec IN 
        SELECT id, created_at 
        FROM donations 
        WHERE order_number IS NULL 
        ORDER BY created_at ASC
    LOOP
        -- 根據記錄的創建日期生成前綴
        date_prefix := 'SD' || TO_CHAR(rec.created_at, 'YYYYMMDD');
        
        -- 如果日期改變，重置計數器
        IF last_date != date_prefix THEN
            last_date := date_prefix;
            counter := 1;
        ELSE
            counter := counter + 1;
        END IF;
        
        -- 更新訂單編號
        UPDATE donations
        SET order_number = date_prefix || '-' || LPAD(counter::TEXT, 3, '0')
        WHERE id = rec.id;
    END LOOP;
END $$;
