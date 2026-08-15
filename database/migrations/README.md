# 資料庫遷移腳本 (SQL only)

> 此資料夾只放 `.sql` 檔案，說明文件請見 `../docs/`

---

## 📋 **SQL 檔案清單（按順序）**

| 編號 | 檔案 | 說明 |
|------|------|------|
| 001 | `001_setup_donations.sql` | 建立基礎贊助表格 |
| 002 | `002_create_audit_logs.sql` | 審計日誌系統 |
| 003 | `003_add_tags.sql` | 贊助標籤系統 |
| 004 | `004_ip_tracking.sql` | IP 位置追蹤 |
| 005 | `005_migrate_to_auth.sql` | 遷移到 Supabase Auth |
| 006 | `006_add_line_name.sql` | LINE 名稱欄位 |
| 007 | `007_create_guides.sql` | 攻略系統 |
| 008 | `008_add_coins_column.sql` | 金幣欄位 |
| 012 | `012_add_total_amount_to_users.sql` | 用戶累計金額 |
| 016 | `016_add_order_number.sql` | 訂單編號 |
| 028 | `028_fix_get_all_users_cumulative_sync.sql` | 累計儲值同步修復 |
| 029 | `029_guides_rls_allow_super_admin.sql` | 攻略 RLS 超級管理員 |
| 030 | `030_guides_rls_fix_42501.sql` | 攻略 RLS 42501 修復 |
| 030 | `030_guides_rls_use_jwt_metadata.sql` | 攻略 RLS 改用 JWT |
| 034 | `034_fix_rls_security.sql` | RLS 安全性修復 |
| 035 | `035_fix_function_search_path.sql` | 函數 search_path 修復 |
| 036 | `036_donations_visible_fix.sql` | 贊助紀錄可見性修復 |
| 037 | `037_donations_temp_allow_all_排查用.sql` | 暫時開放（排查用） |
| 037 | `037_rollback.sql` | 回滾 |
| 038 | `038_donations_admin_only.sql` | 贊助僅管理員 |
| 039 | `039_donations_update_delete_policy_jwt.sql` | 贊助 UPDATE/DELETE 改用 JWT |
| 040 | `040_events_popup_featured.sql` | 活動彈窗主打 (`is_popup_featured`) |
| 041 | `041_events_popup_aspect.sql` | 彈窗圖片比例 (`popup_aspect_ratio`) |
| 042 | `042_events_show_in_popup.sql` | 顯示於彈窗 (`show_in_popup`) |
| 043 | `043_performance_indexes.sql` | 效能索引 |
| 044 | `044_announcements_banner.sql` | 公告橫幅系統 (`announcements` 表) |
| 045 | `045_update_user_profile.sql` | 註冊用戶編輯：資料、角色、遊戲特殊編號 (`update_user_profile` + `get_all_users` 擴充) |
| 046 | `046_five_role_special_ids.sql` | 五個角色各自特殊編號：`game_special_ids` 陣列、列表 5 欄、編輯 Modal 改版 |
| 047 | `047_update_user_game_binding.sql` | 管理員更新會員遊戲綁定 |
| 048 | `048_admin_create_user.sql` | 管理員建立網站會員 |
| 049 | `049_update_user_game_binding_master2.sql` | 第二組遊戲主帳號綁定 |
| 050 | `050_bonus_gold_coupons.sql` | 滿額自動發送加送金幣券、下次儲值套用與核銷 |

---

## 📝 **注意事項**

1. 在 **Supabase Dashboard → SQL Editor** 執行
2. 按編號順序執行
3. 所有腳本使用 `IF NOT EXISTS`，可重複執行
4. 說明文件已移至 `database/docs/`

---

**最後更新：2026-08-15**
