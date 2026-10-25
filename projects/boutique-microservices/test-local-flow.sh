#!/bin/bash
# ==============================================================================
# Automated Local Flow & Verification Test Suite (Bash)
# ==============================================================================

set -e

GATEWAY_URL="http://localhost:3001"
FRONTEND_URL="http://localhost:3000"

echo "=========================================================="
echo "   Boutique Microservices - Local Flow Test Suite"
echo "=========================================================="

# 1. Gateway Health
echo -e "\n[TEST 1] Testing API Gateway Health Check..."
if curl -s -f "$GATEWAY_URL/health" > /dev/null; then
    echo "  [PASS] API Gateway is healthy"
else
    echo "  [FAIL] Failed to reach Gateway at $GATEWAY_URL/health"
fi

# 2. Prometheus Metrics
echo -e "\n[TEST 2] Testing Prometheus Metrics..."
if curl -s "$GATEWAY_URL/metrics" | grep -q "http_requests_total"; then
    echo "  [PASS] Prometheus metrics collected successfully"
else
    echo "  [WARN] Metrics endpoint did not return expected data"
fi

# 3. Rate Limiter Test
echo -e "\n[TEST 3] Testing Rate Limiter (Threshold: 5 req/10s)..."
for i in {1..7}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/test-ratelimit")
    if [ "$STATUS" -eq 429 ]; then
        echo "  [PASS] Request $i correctly rate-limited with HTTP 429 Too Many Requests!"
        break
    fi
done

# 4. Product Catalog Flow
echo -e "\n[TEST 4] Testing Product Catalog Retrieval..."
PROD_RES=$(curl -s "$GATEWAY_URL/api/products")
if echo "$PROD_RES" | grep -q "products"; then
    echo "  [PASS] Retrieved products from catalog"
else
    echo "  [FAIL] Could not query products"
fi

# 5. User Registration Flow
echo -e "\n[TEST 5] Testing User Registration Flow..."
RANDOM_NUM=$((1000 + RANDOM % 9000))
REG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY_URL/api/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"user$RANDOM_NUM@boutique-test.com\",\"password\":\"ProdPassword123!\",\"firstName\":\"Test\",\"lastName\":\"User\"}")

if [ "$REG_STATUS" -eq 201 ] || [ "$REG_STATUS" -eq 200 ]; then
    echo "  [PASS] Registered test user: user$RANDOM_NUM@boutique-test.com (HTTP $REG_STATUS)"
else
    echo "  [FAIL] Registration failed with HTTP $REG_STATUS"
fi

# 6. Frontend UI
echo -e "\n[TEST 6] Testing Frontend UI..."
FRONT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
if [ "$FRONT_STATUS" -eq 200 ]; then
    echo "  [PASS] Frontend UI is serving HTTP 200"
else
    echo "  [FAIL] Frontend returned HTTP $FRONT_STATUS"
fi

echo -e "\n=========================================================="
echo "   Flow Test Completed"
echo "=========================================================="
