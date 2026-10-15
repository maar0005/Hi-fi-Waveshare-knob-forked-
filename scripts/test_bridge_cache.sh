#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary=$(mktemp "${TMPDIR:-/tmp}/bridge-cache.XXXXXX")
headers=$(mktemp -d "${TMPDIR:-/tmp}/bridge-cache-headers.XXXXXX")
trap 'rm -f "$binary"; rm -rf "$headers"' EXIT
mkdir "$headers/lwip"
cp tests/fixtures/bridge_cache/nvs.inc "$headers/nvs.h"
cp tests/fixtures/bridge_cache/inet.inc "$headers/lwip/inet.h"
cc -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I"$headers" -Icommon tests/test_bridge_cache.c \
  common/platform/platform_bridge_cache_esp.c common/platform/platform_mdns_endpoint.c -o "$binary"
"$binary"
