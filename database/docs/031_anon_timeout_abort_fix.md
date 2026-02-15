# 載入速度優化與 AbortError 修復說明

## 問題現象

Console 出現：
- `Supabase error reading playlist: AbortError`
- `Supabase error reading events: AbortError`
- `載入攻略失敗: AbortError`
- `Request was aborted (timeout or manual cancellation)`

## 可能原因

1. **Supabase 專案暫停**（免費方案常見）：專案久未使用被暫停，冷啟動時請求容易逾時
2. **資料庫預設逾時過短**：`anon` 角色預設僅 3 秒，冷啟動或網路慢時易超時
3. **網路不穩定**：請求被中斷

## 已實作優化（前端）

### 載入速度
- **Supabase Preconnect**：預先建立 Supabase 連線，縮短首次請求延遲
- **後台腳本延遲載入**：Chart.js、Quill、Mammoth、PDF.js、SheetJS、html2canvas 改為進入後台時才載入，首頁/攻略/活動等頁面無需等待，可減少約 1–2 秒初始載入時間
- **攻略列表**：僅載入標題等欄位，不載入 content，點擊時再載入
- **攻略圖片**：lazy loading、上傳時壓縮、PDF 轉檔解析度與格式優化

### AbortError 修復

`index.html` 已加入自訂 fetch：
- 遇到 `AbortError` 時自動重試最多 2 次
- 重試間隔約 2.5 秒、5 秒
- 適用於 playlist、events、guides、登入等所有 Supabase 請求

## 建議：調整 Supabase 逾時（選做）

若仍常發生 AbortError，可在 **Supabase Dashboard → SQL Editor** 執行：

```sql
-- 將匿名請求逾時從 3 秒延長為 15 秒
ALTER ROLE anon SET statement_timeout = '15s';
NOTIFY pgrst, 'reload config';
```

驗證是否生效：
```sql
SELECT rolname, rolconfig FROM pg_roles WHERE rolname = 'anon';
```

## 檢查專案是否暫停

1. 登入 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇專案
3. 若看到「Project paused」或「Restore project」，請點擊恢復
4. 恢復後首次請求可能需等待 30 秒～1 分鐘（冷啟動）
