# Cloudflare SPA 與連線設定

## 從 Google 搜尋點進來無法連線（ERR_FAILED）

### 1. 啟用「Always Use HTTPS」

Google 搜尋結果有時會帶 http 連結，需強制轉成 https：

1. Cloudflare Dashboard → 選網域 sodasa.org
2. 左側 **SSL/TLS**
3. 找到 **Edge Certificates**
4. 開啟 **Always Use HTTPS**

### 2. 專案已加入 HTTP→HTTPS 轉址

`_redirects` 已包含 `http://sodasa.org/*` → `https://sodasa.org/:splat` 的 301 轉址。

### 3. 請 Google 重新檢索

1. 到 [Google Search Console](https://search.google.com/search-console)
2. 選擇 sodasa.org
3. 網址檢查 → 輸入 `https://sodasa.org` → 要求編入索引

---

## 會員/後台白畫面

若會員/後台登入後出現白畫面，通常是 Cloudflare 對 `/member`、`/admin`、`/auth` 等路徑回傳 404，需設定讓所有路徑都回傳 `index.html`。

---

## 若使用 **Cloudflare Pages**（Git 部署）

1. 確認專案根目錄**沒有** `404.html`（有的話會關閉 SPA 自動處理）
2. `_redirects` 已存在，部署時會自動套用
3. 重新部署一次

---

## 若使用 **Cloudflare 作為代理**（網站在其他主機）

在 Cloudflare Dashboard 設定 **Redirect Rules**：

1. 登入 [dash.cloudflare.com](https://dash.cloudflare.com)
2. 選擇你的網域
3. 左側 **Rules** → **Redirect Rules**
4. 點 **Create rule**
5. 規則名稱：`SPA Fallback`
6. **When incoming requests match**：選 **Custom filter expression**
7. 輸入：
   ```
   (http.request.uri.path ne "/" and not http.request.uri.path contains "." and http.request.uri.path ne "/index.html")
   ```
   （匹配所有「看起來像路徑」的請求，排除首頁與靜態檔）
8. **Then**：選 **Rewrite URL**
   - Type：**Dynamic**
   - Expression：`concat("/index.html")`
9. **Deploy**

---

## 使用 **Page Rules**（舊版介面）

若找不到 Redirect Rules，可試 **Page Rules**：

1. **Rules** → **Page Rules** → **Create Page Rule**
2. URL：`*sodasa.org/*`（或你的網域）
3. 設定：**Forwarding URL** → **302 Temporary Redirect**
   - 此方式會改變網址列，較不理想
4. 建議優先使用上方的 Redirect Rules
