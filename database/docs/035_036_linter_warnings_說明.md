# Database Linter 其餘警告說明

## 已修復（執行 035）

- **Function Search Path Mutable**：已為 10 個函數加上 `SET search_path = public`

## 未修復（需評估影響）

### 1. RLS Policy Always True

| 表 | 政策 | 說明 |
|----|------|------|
| audit_logs | 允許插入操作日誌 | WITH CHECK (true)，任何人可插入。若僅管理員需寫入，可改為 is_admin(auth.uid()) |
| ip_locations | 允許插入/更新 IP 位置 | 前端用 anon 呼叫 RPC 寫入 IP，若改嚴會導致追蹤失效 |
| sponsorships | Anyone can insert | 贊助表單可能允許匿名送出 |

**建議**：若功能正常，可先維持現狀；若要收緊，需確認前端是否以 anon 寫入。

### 2. Leaked Password Protection Disabled

**說明**：Supabase Auth 可檢查密碼是否在 HaveIBeenPwned 洩漏名單中。

**啟用方式**：Supabase Dashboard → **Authentication** → **Providers** → **Email** → 開啟 **「Leaked password protection」**
