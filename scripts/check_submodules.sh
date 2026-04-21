#!/bin/bash
SRC=/mnt/e/AI_Generated_Projects/rftranslator/_ct2_build_android/CTranslate2
for d in cxxopts thrust googletest cpu_features spdlog ruy cutlass; do
  echo -n "third_party/$d: "
  count=$(ls "$SRC/third_party/$d/" 2>/dev/null | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "EMPTY - needs download"
  else
    echo "has $count items"
  fi
done
