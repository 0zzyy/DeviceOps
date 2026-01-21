#!/bin/bash
set -euo pipefail

if ! command -v swift-openapi-generator >/dev/null 2>&1; then
  echo "swift-openapi-generator not found. Install with: brew install swift-openapi-generator"
  exit 1
fi

swift-openapi-generator generate \
  --config ./openapi-generator-config.yaml \
  ./openapi.yaml

echo "OpenAPI client regenerated."
