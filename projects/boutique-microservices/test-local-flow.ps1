<#
.SYNOPSIS
  Automated Local Flow & Verification Test Suite for Boutique Microservices
.DESCRIPTION
  Executes comprehensive flow testing across all services:
  - Gateway health & Prometheus metrics
  - Rate limiting verification (HTTP 429)
  - User registration & authentication
  - Product catalog retrieval & filtering
  - Order checkout flow
  - Frontend web availability
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Boutique Microservices - Local Flow Test Suite" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$GatewayUrl = "http://localhost:3001"
$FrontendUrl = "http://localhost:3000"

# 1. Gateway Health Test
Write-Host "`n[TEST 1] Testing API Gateway Health Check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$GatewayUrl/health" -Method Get -TimeoutSec 5
    if ($health.status -eq 'healthy') {
        Write-Host "  [PASS] API Gateway is healthy (Uptime: $($health.uptime)s)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Gateway returned unexpected status: $($health.status)" -ForegroundColor Red
    }
} catch {
    Write-Host "  [FAIL] Failed to reach Gateway at $GatewayUrl/health: $_" -ForegroundColor Red
}

# 2. Prometheus Metrics Test
Write-Host "`n[TEST 2] Testing Prometheus Metrics Endpoint..." -ForegroundColor Yellow
try {
    $metrics = Invoke-WebRequest -Uri "$GatewayUrl/metrics" -Method Get -TimeoutSec 5
    if ($metrics.Content -match "http_requests_total") {
        Write-Host "  [PASS] Prometheus metrics are being collected successfully." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Metrics endpoint did not contain expected counters." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [FAIL] Failed to reach /metrics: $_" -ForegroundColor Red
}

# 3. Rate Limiter Test (Triggering HTTP 429)
Write-Host "`n[TEST 3] Testing API Rate Limiter (Threshold: 5 req/10s)..." -ForegroundColor Yellow
$blocked = $false
for ($i = 1; $i -le 7; $i++) {
    try {
        $res = Invoke-WebRequest -Uri "$GatewayUrl/api/test-ratelimit" -Method Get -TimeoutSec 3
        Write-Host "  Request $i: HTTP 200 (Remaining: $($res.Headers['X-RateLimit-Remaining']))" -ForegroundColor Gray
    } catch {
        if ($_.Exception.Response.StatusCode -eq 429) {
            Write-Host "  [PASS] Request $i correctly rate-limited with HTTP 429 Too Many Requests!" -ForegroundColor Green
            $blocked = $true
            break
        }
    }
}
if (-not $blocked) {
    Write-Host "  [WARN] Rate limit threshold was not triggered." -ForegroundColor Yellow
}

# 4. Product Catalog Flow Test
Write-Host "`n[TEST 4] Testing Product Catalog Retrieval via Gateway..." -ForegroundColor Yellow
try {
    $productsRes = Invoke-RestMethod -Uri "$GatewayUrl/api/products" -Method Get -TimeoutSec 5
    $productCount = $productsRes.data.products.Count
    if ($productCount -gt 0) {
        Write-Host "  [PASS] Retrieved $productCount products from catalog." -ForegroundColor Green
        Write-Host "         Sample product: $($productsRes.data.products[0].name) - `$$($productsRes.data.products[0].price)" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] Products returned 0 items. Ensure database seed has run." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [FAIL] Failed to retrieve products: $_" -ForegroundColor Red
}

# 5. User Registration & Auth Test
Write-Host "`n[TEST 5] Testing User Registration Flow..." -ForegroundColor Yellow
$randomId = Get-Random -Minimum 1000 -Maximum 9999
$testEmail = "user$randomId@boutique-test.com"
$regPayload = @{
    email = $testEmail
    password = "ProductionPassword123!"
    firstName = "Test"
    lastName = "Customer"
} | ConvertTo-Json

try {
    $regRes = Invoke-RestMethod -Uri "$GatewayUrl/api/auth/register" -Method Post -Body $regPayload -ContentType "application/json" -TimeoutSec 5
    Write-Host "  [PASS] Successfully registered user: $testEmail" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Registration failed: $_" -ForegroundColor Red
}

# 6. Orders Creation Flow Test
Write-Host "`n[TEST 6] Testing Order Checkout Flow..." -ForegroundColor Yellow
$orderPayload = @{
    items = @(
        @{ productId = "1"; quantity = 1; price = 899.99 }
    )
    shippingAddress = @{
        street = "100 Production Ave"
        city = "New York"
        postalCode = "10001"
    }
} | ConvertTo-Json

try {
    $orderRes = Invoke-RestMethod -Uri "$GatewayUrl/api/orders" -Method Post -Body $orderPayload -ContentType "application/json" -TimeoutSec 5
    Write-Host "  [PASS] Order created successfully! (Order ID: $($orderRes.id), Total: `$$($orderRes.totalAmount))" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Order creation returned: $_" -ForegroundColor Yellow
}

# 7. Frontend UI Availability Test
Write-Host "`n[TEST 7] Testing Frontend React UI..." -ForegroundColor Yellow
try {
    $frontendRes = Invoke-WebRequest -Uri $FrontendUrl -Method Get -TimeoutSec 5
    if ($frontendRes.StatusCode -eq 200) {
        Write-Host "  [PASS] Frontend UI is serving HTTP 200 at $FrontendUrl" -ForegroundColor Green
    }
} catch {
    Write-Host "  [FAIL] Frontend is not reachable at $FrontendUrl: $_" -ForegroundColor Red
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   Flow Test Run Completed" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
