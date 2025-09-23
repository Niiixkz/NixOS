#!/usr/bin bash

set -euo pipefail

cliphist store

cliphist -preview-width 500 list | cut -f1 | xargs -I{} sh -c 'printf "{\"id\":\"%s\",\"content\":%s}\n" "{}" "$(printf "%s" "{}" | cliphist decode | head -15 | jq -Rs .)"' | jq -cs .
