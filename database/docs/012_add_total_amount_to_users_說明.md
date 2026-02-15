# 註冊用戶累計儲值功能

## 更新內容

為「註冊用戶」列表新增**累計儲值金額**的顯示，讓超級管理員可以一目了然地查看每位用戶的儲值情況。

## 新增功能

### 1. 用戶列表新增「累計儲值」欄位
每個用戶顯示：
- 💰 **累計金額**：該用戶所有儲值的總金額（新台幣）
- 🪙 **累計金幣**：該用戶獲得的總金幣數

**顯示格式**：
```
1,500 元
🪙 15,000
```

### 2. 統計卡片新增「累計儲值」
在頂部統計區新增第5個統計卡片：
- 🟠 **累計儲值**：顯示所有用戶的總儲值金額
- 使用橙色主題，Coins 圖標
- 自動計算所有用戶的儲值總和

### 3. 資料關聯
- 透過 `email` 欄位關聯 `auth.users` 和 `donations` 表
- 使用 `LEFT JOIN` 確保沒有儲值記錄的用戶也會顯示（顯示為 0）
- 自動計算每位用戶的 `SUM(amount)` 和 `SUM(coins)`

## 資料庫更新

### SQL 函數修改
修改 `get_all_users()` 函數，新增兩個返回欄位：

```sql
RETURNS TABLE (
    id uuid,
    email character varying,
    created_at timestamptz,
    role text,
    total_amount integer,      -- 新增：累計金額
    total_coins integer         -- 新增：累計金幣
)
```

### 查詢邏輯
```sql
SELECT 
    u.id,
    u.email,
    u.created_at,
    u.raw_user_meta_data->>'role' as role,
    COALESCE(SUM(d.amount), 0)::integer as total_amount,
    COALESCE(SUM(d.coins), 0)::integer as total_coins
FROM auth.users u
LEFT JOIN donations d ON u.email = d.email
GROUP BY u.id, u.email, u.created_at, u.raw_user_meta_data
ORDER BY u.created_at DESC;
```

**說明**：
- `LEFT JOIN`：包含所有用戶，即使沒有儲值記錄
- `COALESCE(..., 0)`：沒有儲值時顯示 0
- `GROUP BY`：按用戶分組統計
- `SUM(d.amount)`：累計金額
- `SUM(d.coins)`：累計金幣

## 使用方式

### 查看用戶儲值情況
1. 進入後台 → **註冊用戶**
2. 在列表中可以看到每位用戶的：
   - Email
   - 角色
   - **累計儲值金額**（元）
   - **累計金幣**（🪙）
   - 註冊時間
   - 操作按鈕

### 查看總儲值統計
在頂部統計卡片中：
- 第1個卡片：總用戶數
- 第2個卡片：超級管理員數量
- 第3個卡片：管理員數量
- 第4個卡片：一般玩家數量
- 第5個卡片：**累計儲值總額** ← 新增

## UI 設計

### 累計儲值欄位（表格）
- 靠右對齊
- 金額：金色大字體（text-gold-400, font-black, text-lg）
- 單位「元」：灰色小字
- 金幣：配合 Coins 圖標，金色字體
- 上下排列，清晰易讀

### 累計儲值卡片（統計區）
- 橙色漸變背景
- Coins 圖標
- 顯示總金額，自動千位分隔
- 例：`150,000 元`

## 部署步驟

### 1. 執行 SQL 更新
在 **Supabase SQL Editor** 執行：
```bash
database/migrations/012_add_total_amount_to_users.sql
```

### 2. 部署前端
1. 刷新 `index.html`
2. 測試「註冊用戶」頁面

### 3. 驗證
- 確認每位用戶的累計儲值正確
- 確認統計卡片的總額正確
- 測試沒有儲值記錄的用戶顯示為 0

## 優勢

1. **一目了然**：快速查看每位用戶的儲值情況
2. **資料完整**：同時顯示金額和金幣
3. **統計直觀**：頂部卡片顯示總儲值
4. **效能優化**：一次查詢獲取所有資料
5. **相容性好**：使用 LEFT JOIN 確保所有用戶都顯示

## 注意事項

- 儲值金額透過 `email` 關聯，確保 `donations` 表的 email 準確
- 累計儲值會包含所有狀態的儲值記錄（pending, completed, failed）
- 如需只統計已完成的儲值，可修改 SQL 加上 `WHERE d.status = 'completed'`

---

**更新時間**：2026-02-01  
**版本**：1.2.0
