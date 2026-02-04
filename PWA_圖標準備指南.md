# 📱 PWA 圖標準備指南

## 🎯 需要準備的圖標尺寸

為了讓您的 PWA 在各種裝置上都能完美顯示，您需要準備以下尺寸的圖標：

### **必須的尺寸**
- `icon-192.png` - 192x192 像素 ✅ **最重要**
- `icon-512.png` - 512x512 像素 ✅ **最重要**

### **建議的尺寸（提升體驗）**
- `icon-72.png` - 72x72 像素
- `icon-96.png` - 96x96 像素
- `icon-128.png` - 128x128 像素
- `icon-144.png` - 144x144 像素
- `icon-152.png` - 152x152 像素
- `icon-384.png` - 384x384 像素

### **其他需要的圖片**
- `og-image.jpg` - 1200x630 像素（用於社群分享）
- `screenshot-mobile.png` - 540x720 像素（手機截圖）
- `screenshot-desktop.png` - 1280x720 像素（桌面截圖）

---

## 🎨 設計建議

### **1. 使用您的 LOGO**
- 最簡單的方式：使用遊戲的主要 LOGO
- 確保 LOGO 在小尺寸下依然清晰可辨

### **2. 設計原則**
- ✅ **簡潔明瞭**：避免複雜的細節
- ✅ **高對比度**：確保在深色/淺色背景都清楚
- ✅ **居中對齊**：圖標內容居中，四周留白
- ✅ **安全區域**：重要內容在圖標中央 80% 區域內

### **3. 顏色建議**
- 背景色：`#fdcb6e`（金色）或 `#1c1917`（深棕色）
- 主體色：與背景形成對比的顏色
- 可以使用品牌色：金色、石色、地色等

---

## 🛠️ 快速製作圖標的方法

### **方法 1：使用線上工具（最簡單）** ⭐ 推薦

1. **PWA Builder Image Generator**
   - 網址：https://www.pwabuilder.com/imageGenerator
   - 上傳一張 512x512 的圖片
   - 自動生成所有尺寸的圖標
   - 一鍵下載打包

2. **RealFaviconGenerator**
   - 網址：https://realfavicongenerator.net/
   - 上傳圖片，自動生成各種圖標
   - 包含 PWA、iOS、Android 圖標

### **方法 2：使用 Photoshop/Figma**

1. 創建 512x512 的畫布
2. 設計您的圖標
3. 依次儲存為不同尺寸：
   - 檔案 → 匯出為 → PNG
   - 設定寬度和高度

### **方法 3：使用 AI 生成器**

如果您沒有設計師，可以使用 AI 工具：
- **DALL-E**、**Midjourney** 生成圖標
- Prompt 範例：
  ```
  "A simple game icon for a Stone Age themed game, 
  featuring a cute dinosaur or stone tool, 
  flat design, minimal, golden and brown colors, 
  white background, app icon style"
  ```

---

## 📦 暫時解決方案（如果沒有圖標）

### **使用文字 LOGO**

如果暫時沒有圖標，我可以幫您創建一個簡單的文字版圖標：

1. 背景：金色 `#fdcb6e`
2. 文字：「蘇打」或「石器」
3. 字體：粗體、黑色

### **快速製作步驟**

使用 HTML Canvas 生成：

```html
<!DOCTYPE html>
<html>
<head>
    <title>Icon Generator</title>
</head>
<body>
    <canvas id="canvas" width="512" height="512"></canvas>
    <button onclick="download()">下載圖標</button>

    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');

        // 背景
        ctx.fillStyle = '#fdcb6e';
        ctx.fillRect(0, 0, 512, 512);

        // 文字
        ctx.fillStyle = '#1c1917';
        ctx.font = 'bold 180px "Noto Sans TC"';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('蘇打', 256, 200);
        ctx.font = 'bold 140px "Noto Sans TC"';
        ctx.fillText('石器', 256, 340);

        function download() {
            const link = document.createElement('a');
            link.download = 'icon-512.png';
            link.href = canvas.toDataURL();
            link.click();
        }
    </script>
</body>
</html>
```

---

## ✅ 檢查清單

準備完成後，請確認：

- [ ] `icon-192.png` 已放在網站根目錄
- [ ] `icon-512.png` 已放在網站根目錄
- [ ] 其他尺寸圖標也已準備（可選）
- [ ] `og-image.jpg` 已準備（用於社群分享）
- [ ] 所有圖標檔案大小 < 200KB
- [ ] 圖標在深色和淺色背景都清楚
- [ ] 在手機上測試圖標顯示

---

## 🚀 測試 PWA 圖標

### **Chrome DevTools**
1. F12 開啟開發者工具
2. 切換到 **Application** 標籤
3. 左側選擇 **Manifest**
4. 查看所有圖標是否正確載入

### **實際測試**
1. 在手機 Chrome 開啟網站
2. 點擊「安裝」或「加入主畫面」
3. 檢查桌面圖標是否正確顯示

---

## 💡 專業建議

### **什麼是 Maskable Icon？**
- Android 12+ 支援的適應性圖標
- 可以適應不同形狀（圓形、方形、圓角方形）
- 建議：重要內容放在中央的「安全區域」內

### **如何製作 Maskable Icon？**
1. 使用工具：https://maskable.app/editor
2. 上傳您的圖標
3. 調整安全區域
4. 預覽在不同形狀下的效果
5. 下載最終版本

---

## 📞 需要幫助？

如果您不確定如何製作圖標，可以：
1. 找一個設計師朋友幫忙
2. 使用線上工具自動生成
3. 或者告訴我您想要的風格，我可以提供更詳細的指導

**最快的方式：使用 PWA Builder 的工具，上傳一張圖片，5 分鐘搞定！** 🎉
