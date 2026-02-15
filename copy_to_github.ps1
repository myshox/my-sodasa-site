# 複製優化檔案到 GitHub 目錄
# Encoding: UTF-8

$source = "c:\Users\mysho\Desktop\蘇打石器"
$destination = "C:\Users\mysho\Documents\GitHub\my-sodasa-site"

Write-Host "Starting file copy to GitHub directory..." -ForegroundColor Green
Write-Host ""

# 需要複製的核心檔案
$coreFiles = @(
    "index.html",
    "manifest.json",
    "sw.js",
    "offline.html",
    "sitemap.xml",
    "robots.txt",
    ".htaccess",
    "_headers",
    "README.md",
    "CHANGELOG.md",
    ".gitignore"
)

# 需要複製的圖標
$iconFiles = @(
    "icon-72.png",
    "icon-96.png",
    "icon-192.png",
    "icon-512.png",
    "og-image.jpg"
)

# 需要複製的圖片
$imageFiles = @(
    "logo.jpg",
    "首頁.jpg",
    "applepay.jpg",
    "jkopay.jpg",
    "LINEPAY.jpg",
    "shopline.jpg",
    "shopline_logo.png",
    "LINE_logo.jpg",
    "LOVE.jpg"
)

# LINE QR 碼
$qrFiles = @(
    "LINE100QR.jpg",
    "LINE300QR.jpg",
    "LINE500QR.jpg",
    "LINE1000QR.jpg",
    "LINE3000QR.jpg",
    "LINE5000QR.jpg",
    "LINE10000QR.jpg"
)

# 音樂檔案
$musicFiles = @(
    "伊甸園.mp3",
    "伊甸大陸.mp3",
    "加魯卡.mp3",
    "戰鬥BGM.mp3",
    "柯奧山的小洞窟.mp3",
    "漆黑洞窟BGM.mp3",
    "薩伊那斯.mp3",
    "薩姆吉爾村.mp3",
    "部落風格鼓聲.mp3",
    "震撼部落.mp3",
    "PK對戰BGM .mp3"
)

Write-Host "[1/6] Copying core files..." -ForegroundColor Cyan
foreach ($file in $coreFiles) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item $src $destination -Force
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  SKIP: $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[2/6] Copying icon files..." -ForegroundColor Cyan
foreach ($file in $iconFiles) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item $src $destination -Force
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  SKIP: $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[3/6] Copying image files..." -ForegroundColor Cyan
foreach ($file in $imageFiles) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item $src $destination -Force
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  SKIP: $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[4/6] Copying QR code files..." -ForegroundColor Cyan
foreach ($file in $qrFiles) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item $src $destination -Force
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  SKIP: $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[5/6] Copying music files..." -ForegroundColor Cyan
foreach ($file in $musicFiles) {
    $src = Join-Path $source $file
    if (Test-Path $src) {
        Copy-Item $src $destination -Force
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  SKIP: $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[6/6] Copying documentation folders..." -ForegroundColor Cyan

# 複製 docs 資料夾
$docsSource = Join-Path $source "docs"
$docsDestination = Join-Path $destination "docs"
if (Test-Path $docsSource) {
    if (-not (Test-Path $docsDestination)) {
        New-Item -ItemType Directory -Path $docsDestination -Force | Out-Null
    }
    Copy-Item "$docsSource\*" $docsDestination -Recurse -Force
    Write-Host "  OK: docs\ folder" -ForegroundColor Green
}

# 複製 database 資料夾
$dbSource = Join-Path $source "database"
$dbDestination = Join-Path $destination "database"
if (Test-Path $dbSource) {
    if (-not (Test-Path $dbDestination)) {
        New-Item -ItemType Directory -Path $dbDestination -Force | Out-Null
    }
    Copy-Item "$dbSource\*" $dbDestination -Recurse -Force
    Write-Host "  OK: database\ folder" -ForegroundColor Green
}

Write-Host ""
Write-Host "[DONE] All files copied successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open GitHub Desktop" -ForegroundColor White
Write-Host "  2. Select 'my-sodasa-site' repository" -ForegroundColor White
Write-Host "  3. Review changes" -ForegroundColor White
Write-Host "  4. Commit with message: '網站全方位優化完成'" -ForegroundColor White
Write-Host "  5. Push to GitHub" -ForegroundColor White
Write-Host ""
