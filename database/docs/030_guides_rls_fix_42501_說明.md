# 攻略儲存 403 / 42501 修復說明

## 錯誤訊息

- `new row violates row-level security policy for table "guides"`
- PostgreSQL 錯誤碼 `42501`（權限不足）
- 或 HTTP `403 Forbidden`

## 解法一：執行 RLS 修復 migration（建議）

1. 開啟 **Supabase Dashboard** → **SQL Editor**
2. 開啟專案中的  
   `database/migrations/030_guides_rls_fix_42501.sql`
3. 複製全部內容，貼到 SQL Editor，按 **Run**
4. 確認沒有錯誤後，回到後台再試一次「儲存攻略」

此 migration 會：

- 新增函數 `public.is_guides_admin()`，用 JWT 的 `user_metadata.role` 與 `auth.users.raw_user_meta_data->>'role'` 判斷是否為管理員
- 將 guides 的 SELECT / INSERT / UPDATE / DELETE 政策改為使用此函數，避免 42501

## 解法二：確認登入帳號有管理員 role

若執行 030 後仍出現 403 / 42501，代表目前登入的使用者在資料庫裡沒有被標成管理員。

1. 在 Supabase Dashboard → **SQL Editor** 執行（把信箱改成你的**後台登入信箱**）：

```sql
UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
WHERE email = '您的後台登入信箱@example.com';
```

2. 或使用專案裡的 `set_admin.sql`，依說明修改 Email 後執行。

3. 執行後請**重新登出再登入後台**，再試一次儲存攻略。

## 如何確認 role 已設定

在 SQL Editor 執行：

```sql
SELECT id, email, raw_user_meta_data->>'role' AS role
FROM auth.users
WHERE email = '您的後台登入信箱@example.com';
```

應看到 `role` 為 `admin` 或 `super_admin`。
