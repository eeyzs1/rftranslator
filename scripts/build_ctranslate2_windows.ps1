$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BuildDir = Join-Path $ProjectRoot "_ct2_build"
$InstallDir = Join-Path $ProjectRoot "windows\libs"
$SourceDir = Join-Path $BuildDir "CTranslate2"

Write-Host "=== CTranslate2 Windows x64 Build Script ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host "Build dir: $BuildDir"
Write-Host "Install dir: $InstallDir"

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Write-Error "CMake not found. Please install CMake 3.16+ and add to PATH."
    exit 1
}

if (-not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022\BuildTools" -ErrorAction SilentlyContinue) -and
    -not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Community" -ErrorAction SilentlyContinue) -and
    -not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Professional" -ErrorAction SilentlyContinue) -and
    -not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Enterprise" -ErrorAction SilentlyContinue)) {
    Write-Error "Visual Studio 2022 Build Tools not found. Please install with C++ Desktop Development workload."
    exit 1
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (-not (Test-Path $SourceDir)) {
    Write-Host "Cloning CTranslate2..." -ForegroundColor Yellow
    Push-Location $BuildDir
    git clone https://github.com/OpenNMT/CTranslate2.git --depth 1 --branch v4.7.0
    Pop-Location
} else {
    Write-Host "Source already exists, skipping clone." -ForegroundColor Green
}

$CMakeBuildDir = Join-Path $BuildDir "build_win64"
New-Item -ItemType Directory -Force -Path $CMakeBuildDir | Out-Null

Write-Host "Configuring CMake..." -ForegroundColor Yellow
Push-Location $CMakeBuildDir

cmake $SourceDir `
    -G "Visual Studio 17 2022" `
    -A x64 `
    -DCMAKE_INSTALL_PREFIX="$InstallDir" `
    -DBUILD_SHARED_LIBS=ON `
    -DWITH_C_API=ON `
    -DWITH_MKL=OFF `
    -DWITH_DNNL=ON `
    -DWITH_CUDA=OFF `
    -DWITH_TFLITE=OFF `
    -DWITH_ONNX=OFF `
    -DWITH_PYTHON=OFF `
    -DWITH_TESTS=OFF `
    -DWITH_EXAMPLES=OFF `
    -DWITH_COVERAGE=OFF `
    -DCMAKE_BUILD_TYPE=Release

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed!"
    Pop-Location
    exit 1
}

Write-Host "Building Release..." -ForegroundColor Yellow
cmake --build . --config Release --parallel

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    Pop-Location
    exit 1
}

Write-Host "Installing..." -ForegroundColor Yellow
cmake --install . --config Release

Pop-Location

Write-Host "Copying DLLs to project..." -ForegroundColor Yellow
$BinDir = Join-Path $CMakeBuildDir "Release"
if (Test-Path $BinDir) {
    Copy-Item (Join-Path $BinDir "ctranslate2.dll") $InstallDir -Force
    Get-ChildItem $BinDir -Filter "*.dll" | Where-Object {
        $_.Name -match "onednn|dnnl|mkl|openblas|omp"
    } | ForEach-Object {
        Copy-Item $_.FullName $InstallDir -Force
        Write-Host "  Copied: $($_.Name)"
    }
}

$LibDir = Join-Path $CMakeBuildDir "Release"
if (-not (Test-Path (Join-Path $InstallDir "ctranslate2.dll"))) {
    $AltBinDir = Join-Path $CMakeBuildDir "bin"
    if (Test-Path (Join-Path $AltBinDir "ctranslate2.dll")) {
        Copy-Item (Join-Path $AltBinDir "ctranslate2.dll") $InstallDir -Force
    }
}

if (Test-Path (Join-Path $InstallDir "ctranslate2.dll")) {
    Write-Host ""
    Write-Host "=== Build Successful! ===" -ForegroundColor Green
    Write-Host "DLL location: $InstallDir\ctranslate2.dll"
    Write-Host ""
    Write-Host "DLLs in install dir:"
    Get-ChildItem $InstallDir -Filter "*.dll" | ForEach-Object {
        Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)"
    }
} else {
    Write-Error "ctranslate2.dll not found after build! Check build output for errors."
    exit 1
}
