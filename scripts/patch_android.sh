#!/bin/bash
set -e

SRC=/mnt/e/AI_Generated_Projects/rftranslator/_ct2_build_android/CTranslate2/src/thread_pool.cc

echo "Patching thread_pool.cc for Android compatibility..."

sed -i 's/#if !defined(__linux__) || defined(_OPENMP)/#if !defined(__linux__) || defined(_OPENMP) || defined(__ANDROID__)/' "$SRC"

echo "Verifying patch..."
grep -n "defined(__ANDROID__)" "$SRC"

echo "Patch applied successfully!"
