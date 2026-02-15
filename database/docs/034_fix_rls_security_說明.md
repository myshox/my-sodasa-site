# Supabase Database Linter 安全修復說明

## 問題摘要

| 表 | 問題 | 風險 |
|----|------|------|
| `donations` | 有 RLS 政策但 RLS 未啟用 | 政策無效，資料可能被不當存取 |
| `admins_backup` | 未啟用 RLS | 任何人可讀取 |
| `admins_backup` | 含 password 欄位且無保護 | 敏感資料外洩 |

## 解決方式

在 **Supabase Dashboard → SQL Editor** 執行：

```
database/migrations/034_fix_rls_security.sql
```

## 修復內容

1. **donations**：啟用 RLS，使既有政策生效
2. **admins_backup**：啟用 RLS 並建立「拒絕所有 API 存取」政策，保護 password 等欄位

## 注意

- `admins_backup` 為舊版 admins 備份，目前應已改用 Supabase Auth
- 修復後，一般 API 無法存取 `admins_backup`
- 如需讀取備份，可透過 Dashboard SQL Editor（使用 service_role）
