#!/bin/bash
set -e

export ANDROID_NDK_HOME=/tmp/android-ndk-r26d
PROJECT_ROOT=/mnt/e/AI_Generated_Projects/rftranslator
BUILD_DIR=$PROJECT_ROOT/_ct2_build_android
SOURCE_DIR=$BUILD_DIR/CTranslate2
INSTALL_DIR=$PROJECT_ROOT/android/app/src/main/jniLibs/arm64-v8a

NDK_PATH=$ANDROID_NDK_HOME
API_LEVEL=21

echo "=== CTranslate2 Android ARM64 Build ==="
echo "NDK path: $NDK_PATH"
echo "Source dir: $SOURCE_DIR"
echo "Install dir: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

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
    -DOPENMP_RUNTIME=NONE \
    -DCMAKE_BUILD_TYPE=Release

echo ""
echo "Building Release..."
cmake --build . --config Release -j$(nproc)

echo ""
echo "Installing..."
cmake --install . --config Release

echo ""
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
