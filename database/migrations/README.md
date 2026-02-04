# 資料庫遷移腳本

> 按照順序執行以建立完整的資料庫結構

---

## 📋 **執行順序**

### **1. setup_donations_additional.sql**
**用途：** 建立基礎贊助表格和相關設定
- 創建 `donations` 表
- 設定 RLS 政策
- 建立索引

**執行時機：** 最先執行

---

### **2. create_audit_logs.sql**
**用途：** 建立審計日誌系統
- 創建 `audit_logs` 表
- 記錄所有管理員操作
- 設定 RLS 政策

**依賴：** 無

---

### **3. add_tags_to_donations.sql**
**用途：** 為贊助記錄加入標籤系統
- 新增 `tags` 欄位（TEXT[]）
- 創建自動標記觸發器
  - VIP 標記（金額 >= 1000）
  - 常客標記（累計 >= 5 次）
- 建立 GIN 索引

**依賴：** setup_donations_additional.sql

---

### **4. add_ip_location_tracking.sql**
**用途：** 建立 IP 位置追蹤系統
- 新增 `ip_address` 和 `ip_location` 欄位
- 創建 `ip_locations` 表（詳細資訊）
- 建立 `upsert_ip_location` RPC 函數

**依賴：** setup_donations_additional.sql

---

### **5. migrate_to_supabase_auth_FIXED.sql**
**用途：** 遷移到 Supabase Auth 認證系統
- 創建輔助函數（is_admin, is_super_admin）
- 更新所有 RLS 政策
- 重命名舊的 admins 表
- 建立審計日誌函數

**依賴：** create_audit_logs.sql

**⚠️ 重要：**
- 執行前請先在 Supabase Dashboard 創建管理員帳號
- 設定 user_metadata: `{"role": "super_admin"}`

---

## 🚀 **快速執行**

### **在 Supabase SQL Editor：**

```sql
-- 1. 基礎設定
\i setup_donations_additional.sql

-- 2. 審計日誌
\i create_audit_logs.sql

-- 3. 標籤系統
\i add_tags_to_donations.sql

-- 4. IP 追蹤
\i add_ip_location_tracking.sql

-- 5. Auth 遷移（最後執行）
\i migrate_to_supabase_auth_FIXED.sql
```

---

## ✅ **驗證**

執行後驗證所有表格是否正確創建：

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;
```

**預期結果：**
- ✅ audit_logs
- ✅ donations
- ✅ ip_locations
- ✅ admins_backup（備份）
- ✅ admins_deprecated（已棄用）

---

## 📝 **注意事項**

1. ⚠️ **執行前請備份資料庫**
2. ⚠️ **按照順序執行**
3. ⚠️ **執行 Auth 遷移前請先創建管理員帳號**
4. ✅ 所有腳本都是冪等的（可重複執行）
5. ✅ 包含錯誤處理機制

---

## 🆘 **遇到錯誤？**

### **ERROR: relation "xxx" does not exist**
- 請確認依賴的表格已創建
- 檢查執行順序是否正確

### **ERROR: permission denied**
- 確認使用的是 service_role key
- 或在 Supabase Dashboard 以 Admin 身份執行

### **ERROR: function already exists**
- 這是正常的，表示函數已創建
- 可以忽略或使用 `CREATE OR REPLACE`

---

**最後更新：2026-02-03**
