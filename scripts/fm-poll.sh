#!/bin/zsh
# Polls the on-device model until it reports available. Read-only observation.
for i in {1..90}; do
  out=$(/tmp/larder-probe 2>&1 | head -1)
  echo "$(date +%H:%M:%S) $out"
  [[ "$out" == *"available)"* ]] && break
  sleep 20
done
