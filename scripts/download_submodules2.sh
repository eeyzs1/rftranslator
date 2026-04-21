#!/bin/bash
set -e

SRC=/mnt/e/AI_Generated_Projects/rftranslator/_ct2_build_android/CTranslate2
TMP=/tmp/ct2_submodules

mkdir -p $TMP

download_with_retry() {
    local name=$1
    local url=$2
    local dest="$SRC/third_party/$name"
    local max_retries=3
    local retry=0

    if [ "$(ls -A $dest 2>/dev/null | wc -l)" -gt 2 ]; then
        echo "$name: already populated, skipping"
        return
    fi

    while [ $retry -lt $max_retries ]; do
        echo "Downloading $name (attempt $((retry+1))/$max_retries)..."
        rm -rf "$dest"
        mkdir -p $dest

        if curl -L --connect-timeout 30 --max-time 300 -o "$TMP/${name}.zip" "$url"; then
            if unzip -q -o "$TMP/${name}.zip" -d "$TMP"; then
                local extracted=$(ls -d "$TMP"/${name}-* 2>/dev/null | head -1)
                if [ -n "$extracted" ]; then
                    cp -r "$extracted"/. "$dest/"
                    echo "  $name: done"
                    rm -rf "$TMP"/${name}-* "$TMP/${name}.zip"
                    return
                fi
            fi
        fi
        echo "  $name: failed, retrying..."
        rm -rf "$TMP"/${name}-* "$TMP/${name}.zip"
        retry=$((retry+1))
        sleep 5
    done
    echo "  $name: FAILED after $max_retries attempts"
}

download_with_retry "spdlog" "https://github.com/gabime/spdlog/archive/refs/heads/v1.x.zip"
download_with_retry "cpu_features" "https://github.com/google/cpu_features/archive/refs/heads/main.zip"
download_with_retry "ruy" "https://github.com/google/ruy/archive/refs/heads/master.zip"
download_with_retry "googletest" "https://github.com/google/googletest/archive/refs/heads/main.zip"

echo ""
echo "=== Status ==="
for d in cxxopts spdlog cpu_features ruy googletest; do
  count=$(ls "$SRC/third_party/$d/" 2>/dev/null | wc -l)
  echo "  third_party/$d: $count items"
done
