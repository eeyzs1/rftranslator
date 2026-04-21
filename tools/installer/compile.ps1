param(
    [string]$IssPath,
    [string]$IsccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

Write-Host "=== Inno Setup Compilation Script ==="
Write-Host "ISCC path: $IsccPath"
Write-Host "ISS path: $IssPath"

$isccExists = Test-Path $IsccPath
Write-Host "ISCC exists: $isccExists"

$issExists = Test-Path $IssPath
Write-Host "ISS exists: $issExists"

if (-not $isccExists) {
    Write-Host "ERROR: ISCC.exe not found at: $IsccPath"
    Write-Host "Searching for ISCC.exe..."
    Get-ChildItem "C:\Program Files" -Recurse -Filter "ISCC.exe" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "Found: $($_.FullName)" }
    Get-ChildItem "C:\Program Files (x86)" -Recurse -Filter "ISCC.exe" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "Found: $($_.FullName)" }
    exit 1
}

if (-not $issExists) {
    Write-Host "ERROR: ISS file not found at: $IssPath"
    exit 1
}

Write-Host "=== ISS file content ==="
Get-Content $IssPath | Write-Host
Write-Host "=== End of ISS file ==="

Write-Host "Running ISCC..."
$output = & $IsccPath $IssPath 2>&1
Write-Host $output

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: ISCC failed with exit code: $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "ISCC completed successfully"
