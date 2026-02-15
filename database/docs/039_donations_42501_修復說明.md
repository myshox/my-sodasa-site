# 修復 permission denied for table users (42501)

## 問題現象

在「贊助管理」或「註冊用戶」相關操作時，更新贊助狀態會失敗，Console 顯示：

- `更新狀態失敗`
- `permission denied for table users` (PostgreSQL 42501)
- HTTP 403 Forbidden

## 原因

donations 表的 **UPDATE** 與 **DELETE** RLS 政策原本使用 `is_admin(auth.uid())`，該函數內部會查詢 `auth.users` 表。

在 Supabase 中，`authenticated` 角色**沒有**直接讀取 `auth.users` 的權限。雖然 `is_admin` 為 `SECURITY DEFINER`，在某些環境下仍會觸發 42501。

## 解決方式

改為使用 **JWT `user_metadata`** 判斷管理員角色，與 donations 的 SELECT 政策（036、038）及 guides 表相同，不查詢 `auth.users`：

```sql
(auth.jwt()->'user_metadata'->>'role') IN ('admin', 'super_admin')
```

## 執行步驟

1. 開啟 Supabase Dashboard → SQL Editor
2. 貼上並執行 `database/migrations/039_donations_update_delete_policy_jwt.sql` 內容

## 若仍無法操作

請確認管理員帳號的 **JWT 已帶有 role**：

1. Supabase Dashboard → **Authentication** → **Users**
2. 點選該管理員 → **raw_user_meta_data** 需包含：`"role": "admin"` 或 `"role": "super_admin"`
3. 若無，可手動補上或執行：
   ```sql
   UPDATE auth.users
   SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role":"super_admin"}'::jsonb
   WHERE email = '您的後台登入信箱';
   ```
4. 更新後請**重新登入**，讓新 JWT 生效。
