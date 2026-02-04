# 🎮 蘇打石器 - 石器時代私服網站

> 經典石器時代私服的官方網站與管理系統

---

## 📋 **專案概覽**

這是一個完整的石器時代私服網站，包含：
- 🌐 **前台網站**：遊戲介紹、活動公告、金幣贊助
- 🔐 **後台管理**：贊助管理、活動管理、音樂管理、統計報表
- 💰 **贊助系統**：整合 Supabase 的完整贊助記錄系統
- 📊 **數據分析**：圖表視覺化、IP 追蹤、審計日誌

---

## 🚀 **技術棧**

### **前端**
- **框架**：React 18 (ESM)
- **路由**：React Router 6
- **樣式**：Tailwind CSS 3
- **動畫**：Framer Motion
- **圖標**：Lucide React
- **圖表**：Chart.js

### **後端**
- **BaaS**：Supabase
  - Authentication（使用者認證）
  - Database（PostgreSQL）
  - Row Level Security（資料安全）
  - Edge Functions（未來擴展）

### **部署**
- **託管**：GitHub Pages
- **CDN**：ESM.sh

---

## 📁 **專案結構**

```
蘇打石器/
├── index.html                          # 主程式（單頁應用）
├── README.md                           # 專案說明
├── .gitignore                          # Git 忽略文件
│
├── database/                           # 資料庫相關
│   ├── migrations/                     # 資料庫遷移腳本
│   │   ├── 001_setup_donations.sql
│   │   ├── 002_create_audit_logs.sql
│   │   ├── 003_add_tags.sql
│   │   ├── 004_ip_tracking.sql
│   │   └── 005_migrate_to_auth.sql
│   │
│   └── docs/                           # 資料庫文檔
│       ├── Supabase_Auth遷移指南.md
│       └── IP位置追蹤實作指南.md
│
└── docs/                               # 專案文檔
    ├── 系統優化建議.md
    ├── 後台優化完成清單.md
    └── 修復完成_React_Hooks錯誤.md
```

---

## 🔧 **功能特色**

### **✨ 前台功能**
- 🏠 首頁（遊戲介紹、特色展示）
- 📥 下載中心（遊戲客戶端、登入器）
- 💬 客服中心（官方 LINE、防詐騙提醒）
- 💰 金幣贊助（多種支付方式）
- 📜 活動公告（最新活動資訊）
- 🎵 背景音樂（石器時代 BGM）

### **🔐 後台管理**
- 📊 **贊助管理**
  - 查看所有贊助記錄
  - 進階搜尋（日期、金額、標籤）
  - 批次操作（多選、批次更新）
  - CSV 導出
  - 標籤系統（VIP、常客自動標記）
  
- 📈 **統計報表**
  - 30 天贊助趨勢圖
  - 支付方式分布（圓餅圖）
  - 熱門方案排行（柱狀圖）
  
- 📢 **活動管理**
  - 新增/編輯/刪除活動
  - 活動標籤分類
  
- 🎵 **音樂管理**
  - 播放清單管理
  
- ⚙️ **設定**
  - 修改管理員密碼
  
- 👥 **超級管理員**
  - 管理其他管理員
  - 角色權限控制

### **🛡️ 安全功能**
- ✅ Supabase Auth 認證（bcrypt 加密）
- ✅ 審計日誌系統（記錄所有操作）
- ✅ Row Level Security（資料庫層級權限控制）
- ✅ IP 位置追蹤（地理位置記錄）
- ✅ 自動備份機制

---

## 🚀 **快速開始**

### **1. Clone 專案**
```bash
git clone https://github.com/yourusername/蘇打石器.git
cd 蘇打石器
```

### **2. 設定 Supabase**

#### **創建 Supabase 專案**
1. 前往 [Supabase](https://supabase.com)
2. 創建新專案
3. 取得 API Keys

#### **執行資料庫遷移**
按照順序執行 `database/migrations/` 中的 SQL 文件：

```sql
-- 1. 基礎設定
001_setup_donations.sql

-- 2. 審計日誌
002_create_audit_logs.sql

-- 3. 標籤系統
003_add_tags.sql

-- 4. IP 追蹤
004_ip_tracking.sql

-- 5. Auth 遷移
005_migrate_to_auth.sql
```

#### **創建管理員帳號**
1. 在 Supabase Dashboard → Authentication → Users
2. 創建新用戶
3. 設定 user_metadata：
```json
{
  "role": "super_admin",
  "display_name": "系統管理員"
}
```

### **3. 修改配置**

編輯 `index.html` 中的 Supabase 配置：
```javascript
const SUPABASE_URL = 'your-project-url';
const SUPABASE_ANON_KEY = 'your-anon-key';
```

### **4. 本地測試**

使用任何 HTTP 伺服器：
```bash
# Python
python -m http.server 8000

# Node.js (http-server)
npx http-server

# VS Code Live Server
# 右鍵 index.html → Open with Live Server
```

### **5. 訪問網站**
```
http://localhost:8000
```

---

## 📊 **資料庫架構**

### **主要資料表**

#### **donations** - 贊助記錄
- `id`: UUID（主鍵）
- `user_id`: UUID（用戶 ID）
- `email`: TEXT（Email）
- `game_account`: TEXT（遊戲帳號）
- `amount`: INTEGER（金額）
- `plan_name`: TEXT（方案名稱）
- `payment_method`: TEXT（支付方式）
- `status`: TEXT（狀態）
- `ip_address`: TEXT（IP 地址）
- `ip_location`: JSONB（位置資訊）
- `tags`: TEXT[]（標籤）
- `created_at`: TIMESTAMP（建立時間）

#### **audit_logs** - 審計日誌
- `id`: BIGSERIAL（主鍵）
- `auth_user_id`: UUID（用戶 ID）
- `admin_username`: TEXT（管理員名稱）
- `action`: TEXT（操作類型）
- `resource_type`: TEXT（資源類型）
- `description`: TEXT（描述）
- `created_at`: TIMESTAMP（時間）

#### **ip_locations** - IP 位置詳情
- `ip_address`: TEXT（主鍵）
- `country`: TEXT（國家）
- `city`: TEXT（城市）
- `latitude`: NUMERIC（緯度）
- `longitude`: NUMERIC（經度）
- `isp`: TEXT（ISP）

---

## 🔐 **管理員登入**

### **登入資訊**
- URL: `https://yourdomain.com/#/admin`
- Email: 您在 Supabase 創建的管理員 Email
- Password: 您設定的密碼

### **角色權限**
- **super_admin**: 完整權限（包含管理其他管理員）
- **admin**: 一般管理權限（無法管理其他管理員）

---

## 📝 **常用操作**

### **查看贊助統計**
```sql
SELECT 
    COUNT(*) as 總筆數,
    SUM(amount) as 總金額,
    AVG(amount) as 平均金額
FROM donations
WHERE status = 'completed';
```

### **查看 IP 分布**
```sql
SELECT 
    il.country,
    COUNT(*) as 次數
FROM donations d
JOIN ip_locations il ON d.ip_address = il.ip_address
GROUP BY il.country
ORDER BY 次數 DESC;
```

### **查看審計日誌**
```sql
SELECT 
    admin_username,
    action,
    description,
    created_at
FROM audit_logs
ORDER BY created_at DESC
LIMIT 50;
```

---

## 🛠️ **維護指南**

### **定期任務**
- ✅ 每週檢查審計日誌
- ✅ 每月備份資料庫
- ✅ 每季檢查安全性更新

### **備份**
Supabase 提供自動備份功能（需在 Dashboard 啟用）

### **監控**
- Supabase Dashboard → Logs
- 瀏覽器 Console（F12）
- 審計日誌表

---

## 📚 **相關文檔**

- [Supabase Auth 遷移指南](./database/docs/Supabase_Auth遷移指南.md)
- [IP 位置追蹤實作指南](./database/docs/IP位置追蹤實作指南.md)
- [系統優化建議](./docs/系統優化建議.md)
- [後台優化完成清單](./docs/後台優化完成清單.md)

---

## 🎯 **未來計劃**

- [ ] 會員等級制度
- [ ] 玩家個人贊助歷史頁面
- [ ] PDF 收據下載功能
- [ ] 虛擬滾動優化（大量數據）
- [ ] 推薦獎勵系統
- [ ] 金流整合（ECPay/NewebPay）

---

## 📄 **授權**

本專案僅供學習和個人使用。

---

## 💬 **聯絡方式**

- **官方 LINE**: @your-line-id
- **Email**: your-email@example.com

---

## 🙏 **致謝**

- [Supabase](https://supabase.com) - 後端服務
- [React](https://react.dev) - 前端框架
- [Tailwind CSS](https://tailwindcss.com) - CSS 框架
- [Chart.js](https://www.chartjs.org) - 圖表庫

---

**最後更新：2026-02-03**
