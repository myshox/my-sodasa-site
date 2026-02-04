# 強制重新部署到 GitHub
# Encoding: UTF-8

$source = "c:\Users\mysho\Desktop\蘇打石器\index.html"
$destination = "C:\Users\mysho\Documents\GitHub\my-sodasa-site\index.html"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  強制重新部署 - 記住帳號密碼功能" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 檢查來源檔案
if (Test-Path $source) {
    $sourceSize = (Get-Item $source).Length
    $sourceLines = (Get-Content $source).Count
    Write-Host "✓ 來源檔案存在" -ForegroundColor Green
    Write-Host "  大小: $($sourceSize / 1KB) KB" -ForegroundColor Gray
    Write-Host "  行數: $sourceLines" -ForegroundColor Gray
} else {
    Write-Host "✗ 來源檔案不存在！" -ForegroundColor Red
    exit
}

# 檢查是否包含新功能
$content = Get-Content $source -Raw
if ($content -match "記住帳號密碼") {
    Write-Host "✓ 檔案包含「記住帳號密碼」功能" -ForegroundColor Green
} else {
    Write-Host "✗ 檔案不包含新功能！" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "正在複製檔案..." -ForegroundColor Yellow

# 刪除舊檔案
if (Test-Path $destination) {
    Remove-Item $destination -Force
    Write-Host "✓ 已刪除舊檔案" -ForegroundColor Green
}

# 複製新檔案
Copy-Item $source $destination -Force
Write-Host "✓ 已複製新檔案" -ForegroundColor Green

# 驗證
if (Test-Path $destination) {
    $destSize = (Get-Item $destination).Length
    $destLines = (Get-Content $destination).Count
    Write-Host ""
    Write-Host "目的檔案資訊：" -ForegroundColor Cyan
    Write-Host "  大小: $($destSize / 1KB) KB" -ForegroundColor Gray
    Write-Host "  行數: $destLines" -ForegroundColor Gray
    
    if ($sourceSize -eq $destSize) {
        Write-Host "✓ 檔案大小相符" -ForegroundColor Green
    } else {
        Write-Host "⚠ 檔案大小不符！" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  檔案已複製完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "接下來請執行：" -ForegroundColor Yellow
Write-Host "  1. 開啟 GitHub Desktop" -ForegroundColor White
Write-Host "  2. 確認看到 index.html 已修改" -ForegroundColor White
Write-Host "  3. Commit: '強制更新：記住帳號密碼功能'" -ForegroundColor White
Write-Host "  4. Push to origin" -ForegroundColor White
Write-Host "  5. 等待 2-3 分鐘" -ForegroundColor White
Write-Host "  6. 用無痕模式測試 https://sodasa.org/#/auth" -ForegroundColor White
Write-Host ""
