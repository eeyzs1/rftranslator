#!/bin/bash
set -e

cd /mnt/e/AI_Generated_Projects/rftranslator/_ct2_build_android/build_android

echo "Resuming build..."
cmake --build . --config Release -j4

echo ""
echo "Copying .so files to project..."
INSTALL_DIR=/mnt/e/AI_Generated_Projects/rftranslator/android/app/src/main/jniLibs/arm64-v8a
mkdir -p "$INSTALL_DIR"

find . -name "libctranslate2.so" -exec cp {} "$INSTALL_DIR/" \;
find /tmp/android-ndk-r26d/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/21/ -name "libc++_shared.so" -exec cp {} "$INSTALL_DIR/" \;

if [ -f "$INSTALL_DIR/libctranslate2.so" ]; then
    echo ""
    echo "=== Build Successful! ==="
    echo "Files in install dir:"
    ls -lh "$INSTALL_DIR/"
else
    echo "ERROR: libctranslate2.so not found after build!"
    exit 1
fi
