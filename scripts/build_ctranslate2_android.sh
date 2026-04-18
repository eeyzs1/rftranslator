#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/_ct2_build_android"
INSTALL_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs/arm64-v8a"
SOURCE_DIR="$BUILD_DIR/CTranslate2"

NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_HOME}/ndk/25.2.9519653}"

echo "=== CTranslate2 Android ARM64 Build Script ==="
echo "Project root: $PROJECT_ROOT"
echo "Build dir: $BUILD_DIR"
echo "Install dir: $INSTALL_DIR"
echo "NDK path: $NDK_PATH"

if [ ! -d "$NDK_PATH" ]; then
    echo "ERROR: Android NDK not found at $NDK_PATH"
    echo "Please set ANDROID_NDK_HOME or ANDROID_HOME environment variable."
    exit 1
fi

TOCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
API_LEVEL=21

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Cloning CTranslate2..."
    cd "$BUILD_DIR"
    git clone https://github.com/OpenNMT/CTranslate2.git --depth 1 --branch v4.7.0
else
    echo "Source already exists, skipping clone."
fi

CMAKE_BUILD_DIR="$BUILD_DIR/build_android"
mkdir -p "$CMAKE_BUILD_DIR"

echo "Configuring CMake for Android ARM64..."
cd "$CMAKE_BUILD_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-$API_LEVEL \
    -DANDROID_STL=c++_shared \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIBS=ON \
    -DWITH_C_API=ON \
    -DWITH_MKL=OFF \
    -DWITH_DNNL=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_TFLITE=OFF \
    -DWITH_ONNX=OFF \
    -DWITH_PYTHON=OFF \
    -DWITH_TESTS=OFF \
    -DWITH_EXAMPLES=OFF \
    -DWITH_COVERAGE=OFF \
    -DCMAKE_BUILD_TYPE=Release

echo "Building Release..."
cmake --build . --config Release -j$(nproc)

echo "Installing..."
cmake --install . --config Release

echo "Copying .so files to project..."
find "$CMAKE_BUILD_DIR" -name "libctranslate2.so" -exec cp {} "$INSTALL_DIR/" \;
find "$CMAKE_BUILD_DIR" -name "libc++_shared.so" -exec cp {} "$INSTALL_DIR/" \;

if [ -f "$INSTALL_DIR/libctranslate2.so" ]; then
    echo ""
    echo "=== Build Successful! ==="
    echo "SO location: $INSTALL_DIR/libctranslate2.so"
    echo ""
    echo "Files in install dir:"
    ls -lh "$INSTALL_DIR/"
else
    echo "ERROR: libctranslate2.so not found after build!"
    exit 1
fi
