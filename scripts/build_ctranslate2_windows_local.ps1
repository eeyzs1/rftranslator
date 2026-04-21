$ErrorActionPreference = "Stop"

$CMAKE = "E:\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$PROJECT_ROOT = "E:\AI_Generated_Projects\rftranslator"
$BUILD_DIR = "$PROJECT_ROOT\_ct2_build_win"
$SOURCE_DIR = "$PROJECT_ROOT\_ct2_build_android\CTranslate2"
$INSTALL_DIR = "$PROJECT_ROOT\windows\libs"
$OPENBLAS_DIR = "$INSTALL_DIR\OpenBLAS"

Write-Host "=== CTranslate2 Windows x64 Build (with OpenBLAS) ===" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null

Write-Host "Configuring CMake with OpenBLAS..." -ForegroundColor Yellow

& $CMAKE $SOURCE_DIR `
    -G "Visual Studio 18 2026" `
    -A x64 `
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" `
    -DBUILD_SHARED_LIBS=ON `
    -DWITH_MKL=OFF `
    -DWITH_DNNL=OFF `
    -DWITH_RUY=OFF `
    -DWITH_OPENBLAS=ON `
    -DWITH_CUDA=OFF `
    -DWITH_TFLITE=OFF `
    -DWITH_ONNX=OFF `
    -DWITH_PYTHON=OFF `
    -DWITH_TESTS=OFF `
    -DWITH_EXAMPLES=OFF `
    -DWITH_COVERAGE=OFF `
    -DOPENMP_RUNTIME=NONE `
    -DCMAKE_BUILD_TYPE=Release `
    -DOPENBLAS_INCLUDE_DIR="$OPENBLAS_DIR\include" `
    -DOPENBLAS_LIBRARY="$OPENBLAS_DIR\openblas.lib" `
    -B $BUILD_DIR

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configuration failed!"
    exit 1
}

Write-Host "Building Release..." -ForegroundColor Yellow
& $CMAKE --build $BUILD_DIR --config Release --parallel

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}

Write-Host "Copying DLLs..." -ForegroundColor Yellow
$binDir = Join-Path $BUILD_DIR "Release"
if (Test-Path $binDir) {
    Copy-Item (Join-Path $binDir "ctranslate2.dll") $INSTALL_DIR -Force
    Write-Host "  Copied: ctranslate2.dll"
}

Copy-Item "$OPENBLAS_DIR\bin\libopenblas.dll" $INSTALL_DIR -Force -ErrorAction SilentlyContinue
if (Test-Path "$INSTALL_DIR\libopenblas.dll") {
    Write-Host "  Copied: libopenblas.dll"
} else {
    Get-ChildItem "$OPENBLAS_DIR" -Recurse -Filter "*.dll" | ForEach-Object {
        Copy-Item $_.FullName $INSTALL_DIR -Force
        Write-Host "  Copied: $($_.Name)"
    }
}

if (Test-Path (Join-Path $INSTALL_DIR "ctranslate2.dll")) {
    Write-Host ""
    Write-Host "=== Build Successful! ===" -ForegroundColor Green
    Write-Host "DLLs in install dir:"
    Get-ChildItem $INSTALL_DIR -Filter "*.dll" | ForEach-Object {
        Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)"
    }
} else {
    Write-Error "ctranslate2.dll not found after build!"
    exit 1
}
