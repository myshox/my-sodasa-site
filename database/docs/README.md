# 資料庫文檔

> 完整的資料庫實作指南和說明

---

## 📚 **文檔列表**

### **1. Supabase_Auth遷移指南.md**
**內容：**
- 從舊的 admins 表遷移到 Supabase Auth
- 完整的步驟說明
- 前端程式碼修改
- 測試驗證方法

**適用對象：** 需要升級認證系統的開發者

---

### **2. IP位置追蹤實作指南.md**
**內容：**
- IP 地理位置追蹤功能
- 資料庫結構設計
- 前端整合方式
- 隱私保護建議
- 實用查詢範例

**適用對象：** 需要追蹤用戶地理位置的開發者

---

## 🗄️ **資料庫架構總覽**

### **核心表格**

#### **donations** - 贊助記錄
```sql
CREATE TABLE donations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    email TEXT NOT NULL,
    game_account TEXT,
    amount INTEGER NOT NULL,
    plan_name TEXT,
    payment_method TEXT,
    status TEXT DEFAULT 'pending',
    notes TEXT,
    ip_address TEXT,
    ip_location JSONB,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### **audit_logs** - 審計日誌
```sql
CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    auth_user_id UUID REFERENCES auth.users(id),
    admin_username TEXT NOT NULL,
    admin_role TEXT,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    description TEXT,
    changes JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### **ip_locations** - IP 位置詳情
```sql
CREATE TABLE ip_locations (
    ip_address TEXT PRIMARY KEY,
    country TEXT,
    country_code TEXT,
    region TEXT,
    city TEXT,
    postal_code TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    timezone TEXT,
    isp TEXT,
    organization TEXT,
    raw_data JSONB,
    query_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 🔧 **輔助函數**

### **is_admin(user_id UUID)**
檢查用戶是否為管理員（admin 或 super_admin）

### **is_super_admin(user_id UUID)**
檢查用戶是否為超級管理員

### **get_admin_info(user_id UUID)**
獲取管理員的完整資訊

### **log_admin_action(...)**
記錄管理員操作到審計日誌

### **upsert_ip_location(...)**
插入或更新 IP 位置資訊

---

## 📊 **常用查詢**

### **贊助統計**
```sql
-- 總覽
SELECT 
    COUNT(*) as 總筆數,
    SUM(amount) as 總金額,
    AVG(amount) as 平均金額,
    COUNT(DISTINCT user_id) as 不重複用戶數
FROM donations
WHERE status = 'completed';

-- 每日統計
SELECT 
    DATE(created_at) as 日期,
    COUNT(*) as 筆數,
    SUM(amount) as 金額
FROM donations
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY 日期 DESC;
```

### **地理位置分析**
```sql
-- 國家排行
SELECT 
    il.country as 國家,
    COUNT(*) as 贊助次數,
    SUM(d.amount) as 總金額
FROM donations d
JOIN ip_locations il ON d.ip_address = il.ip_address
GROUP BY il.country
ORDER BY 總金額 DESC;

-- 城市排行
SELECT 
    il.city as 城市,
    il.country as 國家,
    COUNT(*) as 次數
FROM donations d
JOIN ip_locations il ON d.ip_address = il.ip_address
GROUP BY il.city, il.country
ORDER BY 次數 DESC
LIMIT 10;
```

### **審計日誌查詢**
```sql
-- 最近操作
SELECT 
    admin_username,
    action,
    resource_type,
    description,
    created_at
FROM audit_logs
ORDER BY created_at DESC
LIMIT 50;

-- 特定管理員的操作歷史
SELECT 
    action,
    resource_type,
    description,
    created_at
FROM audit_logs
WHERE admin_username = 'admin@example.com'
ORDER BY created_at DESC;
```

---

## 🔒 **安全性**

### **Row Level Security (RLS)**

所有表格都啟用了 RLS 政策：

- ✅ **donations**: 用戶只能看到自己的記錄，管理員看到全部
- ✅ **audit_logs**: 只有管理員可以查看
- ✅ **ip_locations**: 只有管理員可以查看

### **認證**

- ✅ 使用 Supabase Auth（bcrypt 加密）
- ✅ 密碼強度要求：至少 6 字元
- ✅ Session 管理：自動過期和更新

---

## 📈 **性能優化**

### **索引**
```sql
-- donations 表
CREATE INDEX idx_donations_user_id ON donations(user_id);
CREATE INDEX idx_donations_created_at ON donations(created_at DESC);
CREATE INDEX idx_donations_status ON donations(status);
CREATE INDEX idx_donations_tags ON donations USING GIN(tags);

-- audit_logs 表
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(auth_user_id);

-- ip_locations 表
CREATE INDEX idx_ip_locations_country ON ip_locations(country);
CREATE INDEX idx_ip_locations_city ON ip_locations(city);
```

---

## 🛠️ **維護**

### **定期任務**

#### **清理舊審計日誌（可選）**
```sql
-- 刪除 90 天前的日誌
DELETE FROM audit_logs
WHERE created_at < NOW() - INTERVAL '90 days';
```

#### **更新 IP 查詢次數統計**
```sql
-- 查看最常查詢的 IP
SELECT 
    ip_address,
    country,
    city,
    query_count
FROM ip_locations
ORDER BY query_count DESC
LIMIT 20;
```

---

**最後更新：2026-02-03**
