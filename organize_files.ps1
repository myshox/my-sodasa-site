# =====================================================
# Soda Stone Age - File Organize Script
# =====================================================

# Fix encoding: use UTF-8 so Chinese displays correctly in terminal
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq "ConsoleHost") { chcp 65001 | Out-Null }

Write-Host "[OK] Starting file organize..." -ForegroundColor Cyan
Write-Host ""

# Create folder structure
Write-Host "[1] Creating folders..." -ForegroundColor Yellow
$folders = @(
    "database",
    "database\migrations",
    "database\docs",
    "docs"
)

foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "  + Created: $folder" -ForegroundColor Green
    } else {
        Write-Host "  - Exists: $folder" -ForegroundColor Gray
    }
}

Write-Host ""

# Copy SQL files to database/migrations/
Write-Host "[2] Copying SQL files..." -ForegroundColor Yellow

$sqlFiles = @(
    @{name="setup_donations_additional.sql"; newname="001_setup_donations.sql"},
    @{name="create_audit_logs.sql"; newname="002_create_audit_logs.sql"},
    @{name="add_tags_to_donations.sql"; newname="003_add_tags.sql"},
    @{name="add_ip_location_tracking.sql"; newname="004_ip_tracking.sql"},
    @{name="migrate_to_supabase_auth_FIXED.sql"; newname="005_migrate_to_auth.sql"}
)

foreach ($file in $sqlFiles) {
    $sourcePath = $file.name
    $destPath = "database\migrations\$($file.newname)"
    
    if (Test-Path $sourcePath) {
        if (!(Test-Path $destPath)) {
            Copy-Item $sourcePath $destPath -Force
            Write-Host "  + $sourcePath -> $destPath" -ForegroundColor Green
        } else {
            Write-Host "  - Exists: $destPath" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ! Not found: $sourcePath" -ForegroundColor Red
    }
}

Write-Host ""

# Copy docs to database/docs/
Write-Host "[3] Copying database docs..." -ForegroundColor Yellow

$dbDocs = @(
    "Supabase_Auth遷移指南.md",
    "IP位置追蹤實作指南.md"
)

foreach ($doc in $dbDocs) {
    $destPath = "database\docs\$doc"
    
    if (Test-Path $doc) {
        if (!(Test-Path $destPath)) {
            Copy-Item $doc $destPath -Force
            Write-Host "  + $doc" -ForegroundColor Green
        } else {
            Write-Host "  - Exists: $destPath" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ! Not found: $doc" -ForegroundColor Red
    }
}

Write-Host ""

# Copy project docs to docs/
Write-Host "[4] Copying project docs..." -ForegroundColor Yellow

$projectDocs = @(
    "系統優化建議.md",
    "後台優化完成清單.md",
    "中優先級功能完成清單.md",
    "修復完成_React_Hooks錯誤.md",
    "步驟1完成_Supabase_Auth遷移.md",
    "步驟2完成_IP追蹤已啟用.md",
    "密碼安全性建議.md"
)

foreach ($doc in $projectDocs) {
    $destPath = "docs\$doc"
    
    if (Test-Path $doc) {
        if (!(Test-Path $destPath)) {
            Copy-Item $doc $destPath -Force
            Write-Host "  + $doc" -ForegroundColor Green
        } else {
            Write-Host "  - Exists: $destPath" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ! Not found: $doc" -ForegroundColor Red
    }
}

Write-Host ""

# List old files that can be deleted
Write-Host "[5] Old files you may delete (check first):" -ForegroundColor Yellow

$oldFiles = @(
    "migrate_to_supabase_auth.sql",
    "set_admin.sql",
    "set_super_admin.sql",
    "add_role_to_admins.sql",
    "fix_display_name.sql",
    "create_donations_table.sql",
    "donations_schema.csv"
)

foreach ($file in $oldFiles) {
    if (Test-Path $file) {
        Write-Host "  ? $file" -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "[DONE] File organize complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Check the new folder structure" -ForegroundColor White
Write-Host "  2. Delete old files above if you want" -ForegroundColor White
Write-Host "  3. Run 'git status' to see changes" -ForegroundColor White
Write-Host "  4. Commit with GitHub Desktop" -ForegroundColor White
Write-Host ""
