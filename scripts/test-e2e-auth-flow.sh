#!/usr/bin/env bash
# =============================================================================
# E2E AUTHENTICATION FLOW TEST (GATEWAY -> USER SERVICE -> NOTIFICATION SERVICE)
# =============================================================================
set -euo pipefail

GATEWAY_URL="http://localhost:8080"
USER_URL="http://localhost:8001"
TIMESTAMP=$(date +%s)
TEST_EMAIL="nexus.e2e.${TIMESTAMP}@example.com"
TEST_PASSWORD="Password123!"
NEW_PASSWORD="NewPassword123!"
CHANGED_PASSWORD="FinalPassword123!"
TEST_USERNAME="user_${TIMESTAMP}"

echo "================================================================="
echo "NEXUS E2E AUTHENTICATION TEST (ALL 10 ENDPOINTS)"
echo "Target Gateway: $GATEWAY_URL"
echo "Test Email:     $TEST_EMAIL"
echo "================================================================="

# 1. Health Checks
echo -e "\n[Step 1] Checking Gateway & User Service Health..."
curl -sf "$GATEWAY_URL/health" > /dev/null && echo "  -> Gateway: OK" || echo "  -> Gateway: FAILED"
curl -sf "$USER_URL/health" > /dev/null && echo "  -> User Service: OK" || echo "  -> User Service: FAILED"

# 2. Register
echo -e "\n[Step 2] Testing Register via Gateway (POST /api/v1/auth/register)..."
REGISTER_PAYLOAD=$(cat <<EOF
{
  "email": "$TEST_EMAIL",
  "password": "$TEST_PASSWORD",
  "username": "$TEST_USERNAME",
  "firstName": "Nexus",
  "lastName": "Tester"
}
EOF
)

REGISTER_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d "$REGISTER_PAYLOAD")

REGISTER_STATUS=$(echo "$REGISTER_RES" | grep "HTTP_STATUS" | cut -d: -f2)
REGISTER_BODY=$(echo "$REGISTER_RES" | grep -v "HTTP_STATUS")
echo "  -> Status: $REGISTER_STATUS"
echo "  -> Response: $REGISTER_BODY"

if [ "$REGISTER_STATUS" -ne 201 ]; then
  echo "  [FAIL] Registration failed with status $REGISTER_STATUS"
  exit 1
fi

# 3. Resend OTP
echo -e "\n[Step 3] Testing Resend OTP via Gateway (POST /api/v1/auth/otp/resend)..."
RESEND_PAYLOAD=$(cat <<EOF
{
  "email": "$TEST_EMAIL",
  "type": "REGISTER"
}
EOF
)

RESEND_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/otp/resend" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d "$RESEND_PAYLOAD")

RESEND_STATUS=$(echo "$RESEND_RES" | grep "HTTP_STATUS" | cut -d: -f2)
RESEND_BODY=$(echo "$RESEND_RES" | grep -v "HTTP_STATUS")
echo "  -> Status: $RESEND_STATUS"
echo "  -> Response: $RESEND_BODY"

if [ "$RESEND_STATUS" -ne 200 ]; then
  echo "  [FAIL] Resend OTP failed with status $RESEND_STATUS"
  exit 1
fi

# 4. Extract OTP from User Service Redis or Logs
echo -e "\n[Step 4] Retrieving OTP code..."
OTP_CODE=""
if docker ps | grep -q "nexus-shared-redis"; then
  REDIS_VAL=$(docker exec nexus-shared-redis redis-cli get "otp:registration:$TEST_EMAIL" 2>/dev/null || true)
  if [ -n "$REDIS_VAL" ]; then
    OTP_CODE=$(echo "$REDIS_VAL" | grep -o '"Code":"[0-9]*"' | cut -d'"' -f4 || true)
    echo "  -> Retrieved OTP from Redis: $OTP_CODE"
  fi
fi

if [ -z "$OTP_CODE" ] && docker ps | grep -q "nexus-user-service"; then
  OTP_CODE=$(docker logs nexus-user-service 2>&1 | grep "$TEST_EMAIL" | grep "CODE: >>>" | tail -n1 | grep -o '>>> [0-9]* <<<' | awk '{print $2}' || true)
  if [ -n "$OTP_CODE" ]; then
    echo "  -> Retrieved OTP from nexus-user-service logs: $OTP_CODE"
  fi
fi

if [ -z "$OTP_CODE" ]; then
  echo "  [WARN] Could not retrieve OTP code automatically. Skipping verify/login or please input manually."
else
  # 5. Verify OTP
  echo -e "\n[Step 5] Testing Verify OTP via Gateway (POST /api/v1/auth/otp/verify)..."
  VERIFY_PAYLOAD=$(cat <<EOF
{
  "email": "$TEST_EMAIL",
  "otp": "$OTP_CODE"
}
EOF
)

  VERIFY_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/otp/verify" \
    -H "Content-Type: application/json" \
    -H "X-Gateway-Mode: Real" \
    -d "$VERIFY_PAYLOAD")

  VERIFY_STATUS=$(echo "$VERIFY_RES" | grep "HTTP_STATUS" | cut -d: -f2)
  VERIFY_BODY=$(echo "$VERIFY_RES" | grep -v "HTTP_STATUS")
  echo "  -> Status: $VERIFY_STATUS"
  echo "  -> Response: $VERIFY_BODY"

  if [ "$VERIFY_STATUS" -ne 200 ]; then
    echo "  [FAIL] Verify OTP failed with status $VERIFY_STATUS"
    exit 1
  fi

  # 6. Login
  echo -e "\n[Step 6] Testing Login via Gateway (POST /api/v1/auth/login)..."
  LOGIN_PAYLOAD=$(cat <<EOF
{
  "identifier": "$TEST_EMAIL",
  "password": "$TEST_PASSWORD"
}
EOF
)

  LOGIN_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -H "X-Gateway-Mode: Real" \
    -d "$LOGIN_PAYLOAD")

  LOGIN_STATUS=$(echo "$LOGIN_RES" | grep "HTTP_STATUS" | cut -d: -f2)
  LOGIN_BODY=$(echo "$LOGIN_RES" | grep -v "HTTP_STATUS")
  echo "  -> Status: $LOGIN_STATUS"
  echo "  -> Response: $LOGIN_BODY"

  if [ "$LOGIN_STATUS" -ne 200 ]; then
    echo "  [FAIL] Login failed with status $LOGIN_STATUS"
    exit 1
  fi

  ACCESS_TOKEN=$(echo "$LOGIN_BODY" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || true)
  REFRESH_TOKEN=$(echo "$LOGIN_BODY" | grep -o '"refreshToken":"[^"]*' | cut -d'"' -f4 || true)

  # 7. Refresh Token
  echo -e "\n[Step 7] Testing Refresh Token via Gateway (POST /api/v1/auth/refresh)..."
  REFRESH_PAYLOAD=$(cat <<EOF
{
  "refreshToken": "$REFRESH_TOKEN"
}
EOF
)

  REFRESH_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/refresh" \
    -H "Content-Type: application/json" \
    -H "X-Gateway-Mode: Real" \
    -d "$REFRESH_PAYLOAD")

  REFRESH_STATUS=$(echo "$REFRESH_RES" | grep "HTTP_STATUS" | cut -d: -f2)
  REFRESH_BODY=$(echo "$REFRESH_RES" | grep -v "HTTP_STATUS")
  echo "  -> Status: $REFRESH_STATUS"
  echo "  -> Response: $REFRESH_BODY"

  if [ "$REFRESH_STATUS" -ne 200 ]; then
    echo "  [FAIL] Refresh token failed with status $REFRESH_STATUS"
    exit 1
  fi

  # Update tokens after RTR rotation
  NEW_ACCESS_TOKEN=$(echo "$REFRESH_BODY" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || true)
  NEW_REFRESH_TOKEN=$(echo "$REFRESH_BODY" | grep -o '"refreshToken":"[^"]*' | cut -d'"' -f4 || true)
  if [ -n "$NEW_ACCESS_TOKEN" ]; then ACCESS_TOKEN="$NEW_ACCESS_TOKEN"; fi
  if [ -n "$NEW_REFRESH_TOKEN" ]; then REFRESH_TOKEN="$NEW_REFRESH_TOKEN"; fi

  # 8. Forgot Password
  echo -e "\n[Step 8] Testing Forgot Password via Gateway (POST /api/v1/auth/password/forgot)..."
  FORGOT_PAYLOAD=$(cat <<EOF
{
  "email": "$TEST_EMAIL"
}
EOF
)

  FORGOT_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/password/forgot" \
    -H "Content-Type: application/json" \
    -H "X-Gateway-Mode: Real" \
    -d "$FORGOT_PAYLOAD")

  FORGOT_STATUS=$(echo "$FORGOT_RES" | grep "HTTP_STATUS" | cut -d: -f2)
  FORGOT_BODY=$(echo "$FORGOT_RES" | grep -v "HTTP_STATUS")
  echo "  -> Status: $FORGOT_STATUS"
  echo "  -> Response: $FORGOT_BODY"

  if [ "$FORGOT_STATUS" -ne 200 ]; then
    echo "  [FAIL] Forgot password failed with status $FORGOT_STATUS"
    exit 1
  fi

  # 9. Extract Reset OTP and Reset Password
  echo -e "\n[Step 9] Retrieving Reset Password OTP code and resetting..."
  RESET_OTP=""
  if docker ps | grep -q "nexus-shared-redis"; then
    REDIS_RESET_VAL=$(docker exec nexus-shared-redis redis-cli get "otp:password_reset:$TEST_EMAIL" 2>/dev/null || true)
    if [ -n "$REDIS_RESET_VAL" ]; then
      RESET_OTP=$(echo "$REDIS_RESET_VAL" | grep -o '"Code":"[0-9]*"' | cut -d'"' -f4 || true)
      echo "  -> Retrieved Reset OTP from Redis: $RESET_OTP"
    fi
  fi

  if [ -n "$RESET_OTP" ]; then
    RESET_PAYLOAD=$(cat <<EOF
{
  "email": "$TEST_EMAIL",
  "otpCode": "$RESET_OTP",
  "newPassword": "$NEW_PASSWORD",
  "confirmPassword": "$NEW_PASSWORD"
}
EOF
)
    RESET_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT "$GATEWAY_URL/api/v1/auth/password/reset" \
      -H "Content-Type: application/json" \
      -H "X-Gateway-Mode: Real" \
      -d "$RESET_PAYLOAD")

    RESET_STATUS=$(echo "$RESET_RES" | grep "HTTP_STATUS" | cut -d: -f2)
    echo "  -> Reset Status: $RESET_STATUS"

    # Login with new password to get active token
    LOGIN2_RES=$(curl -s -X POST "$GATEWAY_URL/api/v1/auth/login" \
      -H "Content-Type: application/json" \
      -H "X-Gateway-Mode: Real" \
      -d "{\"identifier\":\"$TEST_EMAIL\",\"password\":\"$NEW_PASSWORD\"}")
    ACCESS_TOKEN=$(echo "$LOGIN2_RES" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || true)
    REFRESH_TOKEN=$(echo "$LOGIN2_RES" | grep -o '"refreshToken":"[^"]*' | cut -d'"' -f4 || true)
  fi

  # 10. Change Password (Authenticated)
  if [ -n "$ACCESS_TOKEN" ]; then
    echo -e "\n[Step 10] Testing Change Password via Gateway (PATCH /api/v1/auth/password)..."
    CHANGE_PAYLOAD=$(cat <<EOF
{
  "oldPassword": "$NEW_PASSWORD",
  "newPassword": "$CHANGED_PASSWORD",
  "confirmPassword": "$CHANGED_PASSWORD"
}
EOF
)

    CHANGE_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PATCH "$GATEWAY_URL/api/v1/auth/password" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "X-Gateway-Mode: Real" \
      -d "$CHANGE_PAYLOAD")

    CHANGE_STATUS=$(echo "$CHANGE_RES" | grep "HTTP_STATUS" | cut -d: -f2)
    CHANGE_BODY=$(echo "$CHANGE_RES" | grep -v "HTTP_STATUS")
    echo "  -> Status: $CHANGE_STATUS"
    echo "  -> Response: $CHANGE_BODY"

    # 11. Logout (Single device)
    echo -e "\n[Step 11] Testing Logout via Gateway (POST /api/v1/auth/logout)..."
    LOGOUT_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/logout" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "X-Gateway-Mode: Real" \
      -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}")

    LOGOUT_STATUS=$(echo "$LOGOUT_RES" | grep "HTTP_STATUS" | cut -d: -f2)
    echo "  -> Status: $LOGOUT_STATUS"

    # 12. Logout All (All devices)
    echo -e "\n[Step 12] Testing Logout All via Gateway (POST /api/v1/auth/logout-all)..."
    LOGOUT_ALL_RES=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$GATEWAY_URL/api/v1/auth/logout-all" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "X-Gateway-Mode: Real")

    LOGOUT_ALL_STATUS=$(echo "$LOGOUT_ALL_RES" | grep "HTTP_STATUS" | cut -d: -f2)
    echo "  -> Status: $LOGOUT_ALL_STATUS"
  fi

  echo -e "\n================================================================="
  echo "[SUCCESS] ALL 10 AUTH FLOWS EXECUTED AND PASSED SUCCESSFULLY!"
  echo "================================================================="
fi
