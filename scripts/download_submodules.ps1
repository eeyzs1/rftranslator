$SRC = "e:\AI_Generated_Projects\rftranslator\_ct2_build_android\CTranslate2\third_party"
$TMP = "e:\AI_Generated_Projects\rftranslator\_ct2_temp_downloads"

New-Item -ItemType Directory -Force -Path $TMP | Out-Null

$submodules = @(
    @{ Name = "spdlog"; Url = "https://github.com/gabime/spdlog/archive/refs/heads/v1.x.zip" },
    @{ Name = "cpu_features"; Url = "https://github.com/google/cpu_features/archive/refs/heads/main.zip" },
    @{ Name = "ruy"; Url = "https://github.com/google/ruy/archive/refs/heads/master.zip" },
    @{ Name = "googletest"; Url = "https://github.com/google/googletest/archive/refs/heads/main.zip" }
)

$mirrors = @(
    "https://ghp.ci/",
    "https://ghproxy.net/",
    ""
)

foreach ($sub in $submodules) {
    $name = $sub.Name
    $url = $sub.Url
    $dest = Join-Path $SRC $name
    $zipFile = Join-Path $TMP "$name.zip"

    $itemCount = (Get-ChildItem $dest -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($itemCount -gt 2) {
        Write-Host "$name : already populated ($itemCount items), skipping" -ForegroundColor Green
        continue
    }

    $downloaded = $false
    foreach ($mirror in $mirrors) {
        $fullUrl = "${mirror}${url}"
        Write-Host "Downloading $name from $fullUrl ..." -ForegroundColor Yellow
        try {
            curl.exe -L --connect-timeout 30 --max-time 300 -o $zipFile $fullUrl
            if (Test-Path $zipFile) {
                $size = (Get-Item $zipFile).Length
                if ($size -gt 1000) {
                    Write-Host "  Extracting $name ($([math]::Round($size/1KB)) KB)..."
                    $extractDir = Join-Path $TMP $name
                    Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
                    
                    $extractedDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
                    if ($extractedDir) {
                        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
                        New-Item -ItemType Directory -Force -Path $dest | Out-Null
                        Get-ChildItem $extractedDir.FullName | Copy-Item -Destination $dest -Recurse -Force
                        Write-Host "  $name : done" -ForegroundColor Green
                        $downloaded = $true
                    }
                    
                    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                    break
                } else {
                    Write-Host "  Downloaded file too small ($size bytes), trying next mirror..." -ForegroundColor Red
                    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Host "  FAILED - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $downloaded) {
        Write-Host "  $name : ALL MIRRORS FAILED" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Status ===" -ForegroundColor Cyan
foreach ($sub in $submodules) {
    $name = $sub.Name
    $dest = Join-Path $SRC $name
    $count = (Get-ChildItem $dest -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  third_party/$name : $count items"
}
