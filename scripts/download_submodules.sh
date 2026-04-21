#!/bin/bash
set -e

SRC=/mnt/e/AI_Generated_Projects/rftranslator/_ct2_build_android/CTranslate2
TMP=/tmp/ct2_submodules

mkdir -p $TMP

download_submodule() {
    local name=$1
    local url=$2
    local dest="$SRC/third_party/$name"

    if [ "$(ls -A $dest 2>/dev/null)" ]; then
        echo "$name: already populated, skipping"
        return
    fi

    echo "Downloading $name..."
    mkdir -p $dest
    curl -sL "$url" -o "$TMP/${name}.zip"
    unzip -q -o "$TMP/${name}.zip" -d "$TMP"
    local extracted=$(ls -d "$TMP"/${name}-* 2>/dev/null | head -1)
    if [ -n "$extracted" ]; then
        cp -r "$extracted"/. "$dest/"
        echo "  $name: done"
    else
        echo "  $name: ERROR - could not find extracted dir"
    fi
    rm -rf "$TMP"/${name}-* "$TMP/${name}.zip"
}

download_submodule "cxxopts" "https://github.com/jarro2783/cxxopts/archive/refs/heads/master.zip"
download_submodule "spdlog" "https://github.com/gabime/spdlog/archive/refs/heads/v1.x.zip"
download_submodule "cpu_features" "https://github.com/google/cpu_features/archive/refs/heads/main.zip"
download_submodule "ruy" "https://github.com/google/ruy/archive/refs/heads/master.zip"
download_submodule "googletest" "https://github.com/google/googletest/archive/refs/heads/main.zip"

echo ""
echo "=== Submodule download complete ==="
for d in cxxopts spdlog cpu_features ruy googletest; do
  count=$(ls "$SRC/third_party/$d/" 2>/dev/null | wc -l)
  echo "  third_party/$d: $count items"
done
