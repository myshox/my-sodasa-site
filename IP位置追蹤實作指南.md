# 🌍 IP 位置追蹤功能實作指南

## 📋 功能概述

這個功能可以追蹤並記錄玩家的 IP 地址和地理位置，用於：
- 🛡️ **安全監控**：偵測異常登入和可疑活動
- 📊 **數據分析**：了解玩家地理分布
- 🚫 **防止詐欺**：識別多重帳號和異常行為
- 🌏 **地區統計**：分析不同地區的贊助狀況

---

## ⚠️ 隱私聲明（重要！）

在實作此功能前，請確保：

1. ✅ **更新隱私政策**：在網站隱私政策中說明會記錄 IP 地址
2. ✅ **合法用途**：僅用於安全、防詐欺、數據分析
3. ✅ **遵守法規**：符合 GDPR、台灣個資法等規範
4. ✅ **資料保留**：建議保留期限 6-12 個月
5. ✅ **存取控制**：IP 資訊僅限管理員查看

---

## 🔧 實作步驟

### **步驟 1：執行 SQL Schema**

在 Supabase Dashboard → SQL Editor 執行：

```sql
執行：add_ip_location_tracking.sql
```

這會建立：
- `ip_locations` 表：儲存 IP 地理位置資訊
- 為 `donations` 表加入 `ip_address` 和 `ip_location` 欄位
- 索引優化查詢效能

### **步驟 2：選擇 IP 定位服務**

推薦的免費 IP 定位 API：

#### **選項 A：ipapi.co（推薦）**
- ✅ 免費額度：1,000 次/天
- ✅ 無需註冊
- ✅ 回應速度快
- ✅ 包含 ISP 資訊
- 📡 API：`https://ipapi.co/{ip}/json/`

#### **選項 B：ip-api.com**
- ✅ 免費額度：45 次/分鐘
- ✅ 無需註冊
- ✅ 支援批次查詢
- 📡 API：`http://ip-api.com/json/{ip}`

#### **選項 C：ipgeolocation.io**
- ✅ 免費額度：1,000 次/天
- ⚠️ 需要註冊取得 API Key
- ✅ 更詳細的資訊
- 📡 API：`https://api.ipgeolocation.io/ipgeo?apiKey={key}&ip={ip}`

### **步驟 3：前端整合（已為您實作）**

我會在 `index.html` 中加入以下功能：

1. **自動取得 IP**：當用戶贊助時自動記錄
2. **查詢地理位置**：使用 IP 定位 API
3. **儲存到資料庫**：記錄到 `donations` 和 `ip_locations`
4. **後台顯示**：在管理員介面顯示 IP 和位置

---

## 📊 後台管理功能

### **贊助管理分頁**
- 顯示每筆贊助的 IP 地址
- 顯示地理位置（國家、城市）
- Hover 顯示詳細資訊（ISP、座標）

### **新增：IP 統計分頁**
- 📍 各國家贊助統計
- 🌆 各城市贊助排行
- 🗺️ 地圖視覺化（可選）
- 📊 異常 IP 偵測

---

## 🔍 查詢範例

### **1. 查看所有 IP 記錄**
```sql
SELECT * FROM ip_locations ORDER BY created_at DESC;
```

### **2. 統計各國家贊助**
```sql
SELECT 
    il.country,
    il.country_code,
    COUNT(d.id) as donation_count,
    SUM(d.amount) as total_amount
FROM donations d
LEFT JOIN ip_locations il ON d.ip_address = il.ip_address
WHERE il.country IS NOT NULL
GROUP BY il.country, il.country_code
ORDER BY donation_count DESC;
```

### **3. 查看特定 IP 的所有活動**
```sql
-- 贊助記錄
SELECT * FROM donations WHERE ip_address = '1.2.3.4';

-- 操作日誌
SELECT * FROM audit_logs WHERE ip_address = '1.2.3.4';
```

### **4. 偵測可疑活動**
```sql
-- 同一 IP 多次贊助
SELECT 
    ip_address,
    COUNT(*) as donation_count,
    SUM(amount) as total_amount,
    array_agg(game_account) as accounts
FROM donations
WHERE ip_address IS NOT NULL
GROUP BY ip_address
HAVING COUNT(*) > 3
ORDER BY donation_count DESC;
```

### **5. 城市排行榜**
```sql
SELECT 
    il.city,
    il.country,
    COUNT(d.id) as count,
    SUM(d.amount) as total
FROM donations d
JOIN ip_locations il ON d.ip_address = il.ip_address
GROUP BY il.city, il.country
ORDER BY count DESC
LIMIT 10;
```

---

## 💻 前端實作範例

### **取得用戶 IP 和位置**

```javascript
// 取得用戶 IP 和地理位置
const getIpLocation = async () => {
    try {
        // 使用 ipapi.co（免費，無需 API key）
        const response = await fetch('https://ipapi.co/json/');
        const data = await response.json();
        
        return {
            ip: data.ip,
            country: data.country_name,
            country_code: data.country_code,
            region: data.region,
            city: data.city,
            postal: data.postal,
            latitude: data.latitude,
            longitude: data.longitude,
            timezone: data.timezone,
            isp: data.org,
            raw_data: data
        };
    } catch (error) {
        console.error('取得 IP 位置失敗:', error);
        return null;
    }
};

// 儲存到資料庫
const saveIpLocation = async (donationId, ipData) => {
    if (!ipData) return;
    
    // 1. 更新 donation 記錄
    await supabase
        .from('donations')
        .update({
            ip_address: ipData.ip,
            ip_location: {
                country: ipData.country,
                city: ipData.city,
                region: ipData.region
            }
        })
        .eq('id', donationId);
    
    // 2. 儲存到 ip_locations 表
    await supabase.rpc('upsert_ip_location', {
        p_ip_address: ipData.ip,
        p_country: ipData.country,
        p_country_code: ipData.country_code,
        p_region: ipData.region,
        p_city: ipData.city,
        p_postal_code: ipData.postal,
        p_latitude: ipData.latitude,
        p_longitude: ipData.longitude,
        p_timezone: ipData.timezone,
        p_isp: ipData.isp,
        p_organization: ipData.isp,
        p_raw_data: ipData.raw_data
    });
};
```

---

## 🛡️ 安全性考量

### **隱私保護**
1. ✅ IP 資訊僅管理員可見
2. ✅ 不在前台顯示其他用戶的 IP
3. ✅ 遵守資料保留政策
4. ✅ 提供用戶刪除資料的管道

### **防止濫用**
1. ✅ Rate Limiting：限制 API 查詢頻率
2. ✅ Cache：重複 IP 直接從資料庫讀取
3. ✅ 錯誤處理：API 失敗不影響主要流程

### **法律合規**
- 📋 更新隱私政策
- 📋 提供資料存取權（GDPR）
- 📋 提供資料刪除權
- 📋 定期審查合規性

---

## 📈 數據分析應用

### **安全監控**
- 🚨 偵測同一 IP 多次註冊
- 🚨 識別異常登入地點
- 🚨 追蹤可疑交易

### **業務洞察**
- 📊 了解主要用戶地區
- 📊 針對熱門地區行銷
- 📊 優化伺服器位置

### **用戶體驗**
- 🌐 自動偵測時區
- 🌐 提供在地化內容
- 🌐 顯示適合的支付方式

---

## 🗺️ 進階功能（可選）

### **地圖視覺化**
使用 Leaflet.js 或 Google Maps 顯示玩家分布

### **即時監控**
在管理後台顯示即時登入地點

### **異常警報**
當偵測到異常 IP 活動時發送通知

---

## 📝 注意事項

### **API 額度管理**
- ipapi.co：1,000 次/天
- 建議：Cache 已查詢的 IP
- 超過額度時使用備用服務

### **隱私政策範例文字**

```
【IP 地址記錄】
為了提供更好的服務並確保帳號安全，我們會記錄您的 IP 地址及其地理位置資訊。
這些資訊僅用於：
- 偵測異常登入和可疑活動
- 統計用戶地理分布
- 改善服務品質

您的 IP 資訊將被安全保存，僅限管理員查看，並在 12 個月後自動刪除。
如有任何疑問，請聯繫我們的客服團隊。
```

---

## 🚀 立即實作

我現在就為您在前端加入 IP 追蹤功能！

**需要我：**
1. ✅ 在贊助時自動記錄 IP
2. ✅ 在後台顯示 IP 和位置
3. ✅ 加入 IP 統計分頁
4. ✅ 實作異常偵測功能

**或者您想要：**
- 🗺️ 加入地圖視覺化
- 📊 更詳細的統計報表
- 🔔 異常 IP 警報系統

請告訴我您的需求！
