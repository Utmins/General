#!/usr/bin/env bash
set -euo pipefail
./Sec-Word_Lists_Inventory.sh --mode=full --parallel=8 --dedup-name=system --out-format=both
