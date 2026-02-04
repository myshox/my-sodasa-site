# 🔐 Supabase Auth 完整遷移指南

> 從舊的 `admins` 表遷移到 Supabase Authentication 系統

---

## 📋 **遷移概覽**

### **為什麼要遷移？**
- ✅ **更安全**：密碼使用業界標準 bcrypt 加密
- ✅ **更完整**：內建密碼重設、MFA、OAuth
- ✅ **更易維護**：不需要自己管理密碼加密邏輯
- ✅ **更專業**：符合現代 Web 應用最佳實踐

### **遷移內容**
1. 將現有管理員從 `admins` 表遷移到 Supabase Auth
2. 更新前端登入邏輯
3. 更新後端 RLS 政策
4. 移除舊的 `admins` 表

---

## ⏱️ **預計時間**
- **準備階段**：10 分鐘
- **執行階段**：20 分鐘
- **測試階段**：10 分鐘
- **總計**：約 40 分鐘

---

## 🚀 **步驟 1：準備工作（Supabase Dashboard）**

### **1.1 在 Supabase 創建管理員帳號**

前往 Supabase Dashboard：
1. 點擊左側選單 **Authentication**
2. 點擊 **Users**
3. 點擊右上角 **Add user** → **Create new user**

#### **創建超級管理員**
```
Email: myshoxisgood@gmail.com
Password: [設定一個新的強密碼]
☑️ Auto Confirm User

點擊「Create user」後，找到剛創建的用戶，點擊進入詳情頁
```

#### **設定用戶 Metadata**
在用戶詳情頁，找到 **User Metadata** 區塊，點擊編輯，輸入：
```json
{
  "role": "super_admin",
  "display_name": "系統管理員"
}
```

點擊 **Save** 儲存。

### **1.2 驗證管理員帳號**

在 Supabase SQL Editor 執行：
```sql
SELECT 
    id,
    email,
    raw_user_meta_data->>'role' as role,
    raw_user_meta_data->>'display_name' as display_name
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'super_admin';
```

應該看到剛創建的管理員帳號。

---

## 🗄️ **步驟 2：執行資料庫遷移（SQL Editor）**

### **2.1 執行遷移 SQL**

在 Supabase SQL Editor 執行我準備好的 SQL 檔案：

**檔案：** `migrate_to_supabase_auth.sql`

**執行順序：**
1. 備份 admins 表 ✅
2. 創建輔助函數 ✅
3. 更新 RLS 政策 ✅
4. 創建管理員視圖 ✅
5. 重命名 admins 表 ✅

### **2.2 驗證遷移結果**

```sql
-- 確認備份已創建
SELECT COUNT(*) FROM admins_backup;

-- 確認輔助函數已創建
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN ('is_admin', 'is_super_admin', 'get_admin_info');

-- 確認舊表已重命名
SELECT table_name 
FROM information_schema.tables 
WHERE table_name LIKE 'admins%';
```

---

## 💻 **步驟 3：更新前端登入邏輯（index.html）**

現在我將更新前端程式碼...

---

## 🧪 **步驟 4：測試新的登入系統**

### **測試清單**

#### **4.1 管理員登入測試**
- [ ] 使用新的 Supabase Auth 帳號登入後台
- [ ] 確認可以看到所有後台分頁
- [ ] 確認「超級管理員」分頁正常顯示

#### **4.2 權限測試**
- [ ] 一般管理員無法看到「超級管理員」分頁
- [ ] 超級管理員可以管理其他管理員
- [ ] 審計日誌正常記錄操作

#### **4.3 功能測試**
- [ ] 贊助管理功能正常
- [ ] 活動管理功能正常
- [ ] 音樂管理功能正常
- [ ] 設定功能正常
- [ ] 統計報表功能正常

#### **4.4 登出測試**
- [ ] 可以正常登出
- [ ] 登出後無法訪問後台

---

## 🔄 **步驟 5：觀察期（建議 7-30 天）**

在確認系統穩定運作後，可以刪除舊表：

```sql
-- 至少等待 7-30 天，確認無問題後執行
DROP TABLE IF EXISTS admins_deprecated CASCADE;
DROP TABLE IF EXISTS admins_backup;
```

---

## 🆘 **步驟 6：回滾計劃（萬一需要）**

如果遷移後發現嚴重問題，可以快速回滾：

```sql
-- 1. 恢復舊表
ALTER TABLE admins_deprecated RENAME TO admins;

-- 2. 恢復舊的前端登入邏輯（從 Git 回退）
-- git checkout HEAD~1 index.html
```

---

## 📊 **遷移前後對比**

### **舊系統（admins 表）**
```javascript
// ❌ 密碼明文或簡單加密
{
  id: 1,
  username: 'admin',
  password: 'password123',  // 不安全！
  role: 'admin'
}

// 登入邏輯
const admin = await supabase
  .from('admins')
  .select()
  .eq('username', username)
  .eq('password', password)  // 明文比對
  .single();
```

### **新系統（Supabase Auth）**
```javascript
// ✅ 使用 bcrypt 加密（自動處理）
// 密碼存儲在 auth.users 表，加密後類似：
// $2a$10$N9qo8uLOickgx2ZMRZoMye...

// 登入邏輯
const { data, error } = await supabase.auth.signInWithPassword({
  email: email,
  password: password  // Supabase 自動驗證加密密碼
});

// 用戶資訊
{
  id: 'uuid',
  email: 'admin@example.com',
  user_metadata: {
    role: 'super_admin',
    display_name: '系統管理員'
  }
}
```

---

## 🎯 **新系統的優勢**

### **1. 安全性提升**
- ✅ 密碼使用 bcrypt (cost factor 10)
- ✅ 支援 MFA（多因素認證）
- ✅ 支援 OAuth（Google、GitHub 等）
- ✅ 自動處理 CSRF 攻擊防護

### **2. 內建功能**
- ✅ 密碼重設（Email 驗證）
- ✅ Email 驗證機制
- ✅ Session 管理
- ✅ Refresh Token 自動輪換

### **3. 管理便利性**
- ✅ Supabase Dashboard 可視化管理
- ✅ 審計日誌自動記錄
- ✅ 可設定密碼強度規則
- ✅ 可設定 Session 過期時間

---

## 📝 **設定密碼政策（可選）**

在 Supabase Dashboard：
1. 前往 **Authentication** → **Policies**
2. 設定密碼強度要求：
   - 最小長度：8 字元
   - 必須包含大小寫
   - 必須包含數字
   - 必須包含特殊符號

---

## 🔐 **密碼重設流程（新功能）**

### **管理員忘記密碼時：**

1. 在登入頁面點擊「忘記密碼」
2. 輸入 Email
3. 收到 Supabase 發送的重設郵件
4. 點擊連結設定新密碼
5. 重新登入

**程式碼已實作**（在前端）：
```javascript
// 已存在於 index.html
const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: `${window.location.origin}/#reset-password`,
});
```

---

## ⚠️ **注意事項**

### **1. 現有管理員需要重新設定密碼**
- 舊密碼無法遷移（因為是明文）
- 需要通知所有管理員使用新密碼登入

### **2. 審計日誌結構變更**
- 新增 `auth_user_id` 欄位（UUID）
- `admin_username` 改為儲存 Email
- 舊的日誌仍然保留

### **3. Session 管理**
- Supabase Auth 使用 JWT Token
- Token 預設 1 小時過期
- Refresh Token 自動更新

---

## ✅ **完成檢查清單**

遷移完成前請確認：

- [ ] 已在 Supabase Auth 創建所有管理員帳號
- [ ] 已執行 `migrate_to_supabase_auth.sql`
- [ ] 已更新前端登入邏輯
- [ ] 已測試管理員登入功能
- [ ] 已測試超級管理員功能
- [ ] 已測試所有後台分頁功能
- [ ] 已測試審計日誌記錄
- [ ] 已通知所有管理員新的登入方式
- [ ] 已備份舊的 admins 表資料

---

## 🎉 **遷移完成後的好處**

1. **✅ 密碼安全**：不再擔心密碼洩露
2. **✅ 易於管理**：Dashboard 可視化管理
3. **✅ 功能完整**：密碼重設、MFA、OAuth
4. **✅ 符合標準**：業界最佳實踐
5. **✅ 可擴展性**：未來可輕鬆加入新功能

---

## 📞 **遇到問題？**

如果遷移過程中遇到問題：

1. **檢查 Supabase Logs**
   - Dashboard → Database → Logs

2. **檢查瀏覽器 Console**
   - F12 → Console 分頁

3. **驗證 RLS 政策**
   - 確認新的 RLS 政策已正確設定

4. **回滾到舊系統**
   - 使用上面提供的回滾步驟

---

**準備好開始遷移了嗎？** 🚀

我現在將更新前端程式碼來完成整個遷移流程！
