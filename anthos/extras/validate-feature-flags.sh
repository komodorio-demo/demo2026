#!/bin/bash
# Validation script for feature-flags ConfigMap
# Prevents common typos that cause production issues

set -e

FLAGS_FILE="$1"

if [ -z "$FLAGS_FILE" ]; then
  echo "Usage: $0 <path-to-feature-flags.yaml>"
  exit 1
fi

if [ ! -f "$FLAGS_FILE" ]; then
  echo "Error: File not found: $FLAGS_FILE"
  exit 1
fi

echo "Validating feature-flags ConfigMap: $FLAGS_FILE"

# Required flag keys that checkout-service expects
REQUIRED_FLAGS=(
  "enable_premium_routing"
  "enable_express_checkout"
  "enable_promo_codes"
)

# Common typos to detect
TYPOS=(
  "enable_premium_routng"  # Missing 'i' - causes 220ms latency instead of 30ms
  "enable_premium_routin"  # Missing 'g'
  "enable_primium_routing" # Typo in 'premium'
)

ERRORS=0

# Extract the flags.yaml content from the ConfigMap
FLAGS_CONTENT=$(yq eval '.data."flags.yaml"' "$FLAGS_FILE")

# Check for required flags
for flag in "${REQUIRED_FLAGS[@]}"; do
  if ! echo "$FLAGS_CONTENT" | grep -q "^$flag:"; then
    echo "❌ ERROR: Required flag '$flag' is missing"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ Found required flag: $flag"
  fi
done

# Check for common typos
for typo in "${TYPOS[@]}"; do
  if echo "$FLAGS_CONTENT" | grep -q "$typo"; then
    echo "❌ ERROR: Detected typo '$typo' - this will cause production issues!"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -eq 0 ]; then
  echo ""
  echo "✅ Validation passed! All required flags present and no typos detected."
  exit 0
else
  echo ""
  echo "❌ Validation failed with $ERRORS error(s)"
  exit 1
fi
