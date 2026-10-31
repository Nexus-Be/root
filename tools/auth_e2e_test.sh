#!/usr/bin/env bash
set -u

GATEWAY="${GATEWAY:-http://localhost:8080}"
REDIS="${REDIS_CONTAINER:-nexus-shared-redis}"
RUN_ID="$(date +%s)"
TMP="$(mktemp -d)"
REPORT="${REPORT:-tools/auth_e2e_report.md}"
EVIDENCE="${EVIDENCE:-tools/auth_e2e_evidence.md}"
FAILED=0
PASSED=0
HTTP=""
BODY=""
NEW_USER_ID=""
CREATED_IDS=()
ADMIN_TOKEN=""

mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"
: > "$EVIDENCE"

cleanup() {
    if [ -n "${ADMIN_TOKEN}" ]; then
        for id in "${CREATED_IDS[@]:-}"; do
            [ -n "$id" ] || continue
            curl -sS -o /dev/null -X DELETE "$GATEWAY/api/v1/admin/users/$id" \
                -H "Authorization: Bearer $ADMIN_TOKEN" \
                -H 'Content-Type: application/json' \
                -d '{"reason":"QA auth e2e cleanup"}' || true
        done
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT

header() { printf '\n## %s\n' "$1" | tee -a "$REPORT"; }
pass() { PASSED=$((PASSED + 1)); printf 'PASS  %-14s %s\n' "$1" "$2" | tee -a "$REPORT"; }
fail() {
    FAILED=$((FAILED + 1))
    printf 'FAIL  %-14s %s | http=%s body=%s\n' "$1" "$2" "$HTTP" "$BODY" | tee -a "$REPORT"
}

call() {
    local method="$1" path="$2" body="${3:-}" token="${4:-}"
    clear_rate_limits
    local args=(-sS -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -X "$method" "$GATEWAY$path")
    if [ -n "$body" ]; then args+=(-H 'Content-Type: application/json' -d "$body"); fi
    if [ -n "$token" ]; then args+=(-H "Authorization: Bearer $token"); fi
    HTTP=$(curl "${args[@]}")
    BODY=$(cat "$TMP/body")
}

error_code() { printf '%s' "$BODY" | jq -r '.errorCode // empty' 2>/dev/null || true; }

expect_status() {
    if [ "$HTTP" = "$3" ]; then pass "$1" "$2"; else fail "$1" "$2 (expected HTTP $3)"; fi
}

expect_error() {
    local code
    code=$(error_code)
    if [ "$HTTP" = "$3" ] && [ "$code" = "$4" ]; then
        pass "$1" "$2"
    else
        fail "$1" "$2 (expected HTTP $3/$4, got $HTTP/$code)"
    fi
}

expect_jq() {
    if printf '%s' "$BODY" | jq -e "$3" >/dev/null 2>&1; then
        pass "$1" "$2"
    else
        fail "$1" "$2 (jq assertion failed: $3)"
    fi
}

expect_header() {
    if grep -qi "^$3:" "$TMP/headers"; then pass "$1" "$2"; else fail "$1" "$2 (missing header $3)"; fi
}

save_evidence() {
    {
        printf '\n### %s\n\n' "$1"
        printf '%s' "$BODY" | jq . 2>/dev/null || printf '%s\n' "$BODY"
    } >> "$EVIDENCE"
}

clear_rate_limits() {
    local keys key
    keys=$(docker exec "$REDIS" redis-cli --scan --pattern 'nexus:gateway:rate:strict:*' 2>/dev/null || true)
    if [ -n "$keys" ]; then
        while IFS= read -r key; do
            [ -n "$key" ] || continue
            docker exec "$REDIS" redis-cli DEL "$key" >/dev/null 2>&1 || true
        done <<< "$keys"
    fi
}

clear_login_state() {
    docker exec "$REDIS" redis-cli DEL "user:login_attempts:$1" "user:login_lockout:$1" >/dev/null 2>&1 || true
}

get_otp() {
    docker exec "$REDIS" redis-cli --raw GET "otp:$2:$1" 2>/dev/null | jq -r '.Code // empty' 2>/dev/null || true
}

new_email() { printf 'qa+%s+%s@nexus.local' "$1" "$RUN_ID"; }

register_pending() {
    local email="$1"
    call POST /api/v1/auth/register \
        "{\"email\":\"$email\",\"password\":\"Password123!\",\"firstName\":\"Qa\",\"lastName\":\"Tester\"}"
    NEW_USER_ID=$(printf '%s' "$BODY" | jq -r '.data.userId // empty' 2>/dev/null || true)
}

activate_user() {
    local email="$1" otp
    otp=$(get_otp "$email" registration)
    call POST /api/v1/auth/otp/verify "{\"email\":\"$email\",\"otp\":\"$otp\"}"
}

login_user() {
    call POST /api/v1/auth/login "{\"identifier\":\"$1\",\"password\":\"$2\"}"
}

SEMVER="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
header "Auth E2E through Gateway - $SEMVER"
printf 'Gateway `%s`, run `%s`.\n' "$GATEWAY" "$RUN_ID" | tee -a "$REPORT"

# ---------------------------------------------------------------- AUTH-01 register
header "AUTH-01 POST /api/v1/auth/register"
EMAIL_MAIN=$(new_email main)
register_pending "$EMAIL_MAIN"; USER_ID="$NEW_USER_ID"
CREATED_IDS+=("$USER_ID")
expect_status "AUTH-01-01" "New account returns 201" 201
expect_jq "AUTH-01-02" "Envelope has userId, email and otpExpiresIn=300" \
    '.success == true and .statusCode == 201 and (.data.userId | length) > 0 and .data.email == "'"$EMAIL_MAIN"'" and .data.otpExpiresIn == 300'
[ -n "$(get_otp "$EMAIL_MAIN" registration)" ] && pass "AUTH-01-03" "OTP is stored in Redis" || fail "AUTH-01-03" "OTP missing in Redis"
save_evidence "register success"

clear_rate_limits
call POST /api/v1/auth/register '{"email":"not-an-email","password":"Password123!","firstName":"Qa","lastName":"Tester"}'
expect_error "AUTH-01-04" "Invalid email" 400 VAL_INVALID_EMAIL

clear_rate_limits
call POST /api/v1/auth/register '{"email":"qa+short@nexus.local","password":"short","firstName":"Qa","lastName":"Tester"}'
expect_error "AUTH-01-05" "Password shorter than 8 characters" 400 VAL_INVALID_PASSWORD

clear_rate_limits
call POST /api/v1/auth/register '{"email":"buyer@nexus.com","password":"Password123!","firstName":"Qa","lastName":"Tester"}'
expect_error "AUTH-01-06" "Active email is rejected" 400 EMAIL_ALREADY_EXISTS

# ---------------------------------------------------------------- AUTH-02 otp verify
header "AUTH-02 POST /api/v1/auth/otp/verify"
OTP_MAIN=$(get_otp "$EMAIL_MAIN" registration)
clear_rate_limits
call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_MAIN\",\"otp\":\"$OTP_MAIN\"}"
expect_status "AUTH-02-01" "Valid OTP activates the account" 200
expect_jq "AUTH-02-02" "Response reports isVerified and buyer role" \
    '.data.isVerified == true and (.data.roles | index("buyer")) != null'
save_evidence "otp verify success"

EMAIL_WRONG=$(new_email verifywrong)
register_pending "$EMAIL_WRONG"; USER_WRONG="$NEW_USER_ID"
CREATED_IDS+=("$USER_WRONG")
clear_rate_limits
call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_WRONG\",\"otp\":\"000000\"}"
WRONG_OTP=$(get_otp "$EMAIL_WRONG" registration)
if [ "$WRONG_OTP" = "000000" ]; then
    call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_WRONG\",\"otp\":\"000001\"}"
fi
expect_error "AUTH-02-03" "Wrong OTP is rejected" 400 OTP_INVALID

clear_rate_limits
call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_MAIN\",\"otp\":\"$OTP_MAIN\"}"
expect_error "AUTH-02-04" "Reusing a consumed OTP is rejected" 400 OTP_ALREADY_USED

EMAIL_EXPIRED=$(new_email expired)
register_pending "$EMAIL_EXPIRED"; USER_EXPIRED="$NEW_USER_ID"
CREATED_IDS+=("$USER_EXPIRED")
OTP_EXPIRED=$(get_otp "$EMAIL_EXPIRED" registration)
docker exec "$REDIS" redis-cli DEL "otp:registration:$EMAIL_EXPIRED" >/dev/null 2>&1 || true
clear_rate_limits
call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_EXPIRED\",\"otp\":\"$OTP_EXPIRED\"}"
expect_error "AUTH-02-05" "Expired OTP is rejected" 400 OTP_EXPIRED

clear_rate_limits
call POST /api/v1/auth/otp/verify '{"email":"qa+missing+'"$RUN_ID"'@nexus.local","otp":"123456"}'
expect_error "AUTH-02-06" "Unknown account is rejected" 400 USER_NOT_FOUND

# ---------------------------------------------------------------- AUTH-03 otp resend
header "AUTH-03 POST /api/v1/auth/otp/resend"
EMAIL_RESEND=$(new_email resend)
register_pending "$EMAIL_RESEND"; USER_RESEND="$NEW_USER_ID"
CREATED_IDS+=("$USER_RESEND")
OLD_OTP=$(get_otp "$EMAIL_RESEND" registration)
clear_rate_limits
call POST /api/v1/auth/otp/resend "{\"email\":\"$EMAIL_RESEND\"}"
expect_status "AUTH-03-01" "Resend returns 200" 200
expect_jq "AUTH-03-02" "Response advertises a 60 second cooldown" '.data.resendCooldown == 60'
NEW_OTP=$(get_otp "$EMAIL_RESEND" registration)
if [ -n "$NEW_OTP" ] && [ "$NEW_OTP" != "$OLD_OTP" ]; then pass "AUTH-03-03" "Resend rotates the OTP"; else fail "AUTH-03-03" "OTP did not rotate"; fi
save_evidence "otp resend success"

clear_rate_limits
call POST /api/v1/auth/otp/resend '{"email":"buyer@nexus.com"}'
expect_error "AUTH-03-04" "Verified account cannot resend" 400 USER_ALREADY_VERIFIED

clear_rate_limits
call POST /api/v1/auth/otp/resend '{"email":"qa+missing+'"$RUN_ID"'@nexus.local"}'
expect_error "AUTH-03-05" "Unknown account cannot resend" 400 USER_NOT_FOUND

# ---------------------------------------------------------------- AUTH-04 login
header "AUTH-04 POST /api/v1/auth/login"
clear_rate_limits
clear_login_state "$EMAIL_MAIN"
login_user "$EMAIL_MAIN" "Password123!"
expect_status "AUTH-04-01" "Valid credentials return 200" 200
expect_jq "AUTH-04-02" "Tokens and user profile are returned" \
    '(.data.accessToken | length) > 0 and (.data.refreshToken | length) > 0 and .data.tokenType == "Bearer" and (.data.roles | index("buyer")) != null'
MAIN_TOKEN=$(printf '%s' "$BODY" | jq -r '.data.accessToken')
MAIN_REFRESH=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')
save_evidence "login success"

clear_login_state "$EMAIL_MAIN"
call POST /api/v1/auth/login "{\"identifier\":\"$EMAIL_MAIN\",\"password\":\"WrongPassword1!\"}"
expect_error "AUTH-04-03" "Wrong password is rejected" 401 INVALID_CREDENTIALS

EMAIL_PENDING=$(new_email pending)
register_pending "$EMAIL_PENDING"; USER_PENDING="$NEW_USER_ID"
CREATED_IDS+=("$USER_PENDING")
clear_login_state "$EMAIL_PENDING"
call POST /api/v1/auth/login "{\"identifier\":\"$EMAIL_PENDING\",\"password\":\"Password123!\"}"
expect_error "AUTH-04-04" "Pending account cannot log in" 403 ACCOUNT_NOT_VERIFIED

clear_rate_limits
clear_login_state "$USER_PENDING"
for _ in 1 2 3 4 5; do
    call POST /api/v1/auth/login "{\"identifier\":\"$USER_PENDING\",\"password\":\"WrongPassword1!\"}"
done
ATTEMPT_CODE=$(error_code)
if [ "$HTTP" = "423" ] && [ "$ATTEMPT_CODE" = "ACCOUNT_LOCKED_TEMPORARY" ]; then
    pass "AUTH-04-05" "Fifth failed attempt locks the account"
else
    fail "AUTH-04-05" "Expected 423/ACCOUNT_LOCKED_TEMPORARY (got $HTTP/$ATTEMPT_CODE)"
fi
clear_login_state "$USER_PENDING"

clear_rate_limits
clear_login_state "admin@nexus.com"
login_user "admin@nexus.com" "Password123!"
if [ "$HTTP" = "200" ]; then
    ADMIN_TOKEN=$(printf '%s' "$BODY" | jq -r '.data.accessToken')
    pass "AUTH-04-06" "Seed admin can log in"
else
    fail "AUTH-04-06" "Seed admin login failed"
fi

# ---------------------------------------------------------------- AUTH-05 refresh
header "AUTH-05 POST /api/v1/auth/refresh"
clear_rate_limits
call POST /api/v1/auth/refresh "{\"refreshToken\":\"$MAIN_REFRESH\"}"
expect_status "AUTH-05-01" "Refresh rotates the session" 200
expect_jq "AUTH-05-02" "New access and refresh tokens are returned" \
    '(.data.accessToken | length) > 0 and (.data.refreshToken | length) > 0'
ROTATED_REFRESH=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')
save_evidence "refresh success"

call POST /api/v1/auth/refresh "{\"refreshToken\":\"$MAIN_REFRESH\"}"
expect_error "AUTH-05-03" "Old refresh token is rejected" 400 REFRESH_TOKEN_REVOKED

call POST /api/v1/auth/refresh '{"refreshToken":"not-a-real-token"}'
expect_error "AUTH-05-04" "Unknown refresh token is rejected" 400 INVALID_REFRESH_TOKEN

call POST /api/v1/auth/refresh '{}'
expect_error "AUTH-05-05" "Missing refresh token is rejected" 400 VAL_INVALID_INPUT

# ---------------------------------------------------------------- AUTH-06 forgot password
header "AUTH-06 POST /api/v1/auth/password/forgot"
clear_rate_limits
call POST /api/v1/auth/password/forgot "{\"email\":\"$EMAIL_MAIN\"}"
expect_status "AUTH-06-01" "Forgot password returns 200" 200
expect_jq "AUTH-06-02" "Generic response contains the email" '.data.email == "'"$EMAIL_MAIN"'"'
RESET_OTP=$(get_otp "$EMAIL_MAIN" password_reset)
if [ -n "$RESET_OTP" ]; then pass "AUTH-06-03" "Password reset OTP is stored"; else fail "AUTH-06-03" "Password reset OTP missing"; fi
save_evidence "forgot password success"

clear_rate_limits
call POST /api/v1/auth/password/forgot '{"email":"qa+missing+'"$RUN_ID"'@nexus.local"}'
expect_status "AUTH-06-04" "Unknown email still returns generic 200" 200
if [ -z "$(get_otp "qa+missing+$RUN_ID@nexus.local" password_reset)" ]; then
    pass "AUTH-06-05" "No OTP is created for unknown email"
else
    fail "AUTH-06-05" "OTP created for unknown email"
fi

call POST /api/v1/auth/password/forgot '{"email":"bad-email"}'
expect_error "AUTH-06-06" "Invalid email format is rejected" 400 VAL_INVALID_EMAIL

# ---------------------------------------------------------------- AUTH-07 reset password
header "AUTH-07 PUT /api/v1/auth/password/reset"
clear_rate_limits
call PUT /api/v1/auth/password/reset \
    "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"$RESET_OTP\",\"newPassword\":\"NewPassword123!\",\"confirmPassword\":\"NewPassword123!\"}"
expect_status "AUTH-07-01" "Valid reset OTP changes the password" 200
expect_jq "AUTH-07-02" "Response reports success" '.data.success == true'
save_evidence "reset password success"

clear_rate_limits
clear_login_state "$EMAIL_MAIN"
login_user "$EMAIL_MAIN" "Password123!"
expect_error "AUTH-07-03" "Old password no longer works" 401 INVALID_CREDENTIALS

clear_rate_limits
clear_login_state "$EMAIL_MAIN"
login_user "$EMAIL_MAIN" "NewPassword123!"
expect_status "AUTH-07-04" "New password works" 200

clear_rate_limits
call PUT /api/v1/auth/password/reset \
    "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"$RESET_OTP\",\"newPassword\":\"AnotherPassword1!\",\"confirmPassword\":\"AnotherPassword1!\"}"
expect_error "AUTH-07-05" "Reusing reset OTP is rejected" 400 OTP_ALREADY_USED

clear_rate_limits
call POST /api/v1/auth/password/forgot "{\"email\":\"$EMAIL_MAIN\"}"
RESET_OTP2=$(get_otp "$EMAIL_MAIN" password_reset)
call PUT /api/v1/auth/password/reset \
    "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"000000\",\"newPassword\":\"AnotherPassword1!\",\"confirmPassword\":\"AnotherPassword1!\"}"
if [ "$RESET_OTP2" = "000000" ]; then
    call PUT /api/v1/auth/password/reset \
        "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"000001\",\"newPassword\":\"AnotherPassword1!\",\"confirmPassword\":\"AnotherPassword1!\"}"
fi
expect_error "AUTH-07-06" "Wrong reset OTP is rejected" 400 OTP_INVALID

call PUT /api/v1/auth/password/reset \
    "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"$RESET_OTP2\",\"newPassword\":\"AnotherPassword1!\",\"confirmPassword\":\"DifferentPassword1!\"}"
expect_error "AUTH-07-07" "Password confirmation mismatch is rejected" 400 VAL_PASSWORD_MISMATCH

call PUT /api/v1/auth/password/reset \
    "{\"email\":\"$EMAIL_MAIN\",\"otpCode\":\"$RESET_OTP2\",\"newPassword\":\"short\",\"confirmPassword\":\"short\"}"
expect_error "AUTH-07-08" "Short reset password is rejected" 400 VAL_INVALID_PASSWORD

# ---------------------------------------------------------------- AUTH-08 change password
header "AUTH-08 PATCH /api/v1/auth/password"
EMAIL_CHANGE=$(new_email change)
register_pending "$EMAIL_CHANGE"; USER_CHANGE="$NEW_USER_ID"
CREATED_IDS+=("$USER_CHANGE")
activate_user "$EMAIL_CHANGE"
clear_rate_limits
clear_login_state "$EMAIL_CHANGE"
login_user "$EMAIL_CHANGE" "Password123!"
CHANGE_TOKEN=$(printf '%s' "$BODY" | jq -r '.data.accessToken')
CHANGE_REFRESH=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')

call PATCH /api/v1/auth/password '{"oldPassword":"Password123!","newPassword":"ChangedPassword1!","confirmPassword":"ChangedPassword1!"}'
expect_error "AUTH-08-01" "Change password without JWT is rejected" 401 UNAUTHORIZED

call PATCH /api/v1/auth/password \
    '{"oldPassword":"Password123!","newPassword":"ChangedPassword1!","confirmPassword":"ChangedPassword1!"}' "$CHANGE_TOKEN"
expect_status "AUTH-08-02" "Authenticated change password returns 200" 200
expect_jq "AUTH-08-03" "Response reports success" '.data.success == true'
save_evidence "change password success"

call POST /api/v1/auth/refresh "{\"refreshToken\":\"$CHANGE_REFRESH\"}"
expect_error "AUTH-08-04" "Change password revokes existing refresh tokens" 400 REFRESH_TOKEN_REVOKED

clear_rate_limits
clear_login_state "$EMAIL_CHANGE"
login_user "$EMAIL_CHANGE" "ChangedPassword1!"
CHANGE_TOKEN2=$(printf '%s' "$BODY" | jq -r '.data.accessToken')

call PATCH /api/v1/auth/password \
    '{"oldPassword":"WrongOldPassword1!","newPassword":"AnotherPassword1!","confirmPassword":"AnotherPassword1!"}' "$CHANGE_TOKEN2"
expect_error "AUTH-08-05" "Wrong old password is rejected" 400 INVALID_CREDENTIALS

call PATCH /api/v1/auth/password \
    '{"oldPassword":"ChangedPassword1!","newPassword":"ChangedPassword1!","confirmPassword":"ChangedPassword1!"}' "$CHANGE_TOKEN2"
expect_error "AUTH-08-06" "Reusing the current password is rejected" 400 VAL_SAME_PASSWORD

# ---------------------------------------------------------------- AUTH-09 logout
header "AUTH-09 POST /api/v1/auth/logout"
EMAIL_LOGOUT=$(new_email logout)
register_pending "$EMAIL_LOGOUT"; USER_LOGOUT="$NEW_USER_ID"
CREATED_IDS+=("$USER_LOGOUT")
activate_user "$EMAIL_LOGOUT"
clear_rate_limits
clear_login_state "$EMAIL_LOGOUT"
login_user "$EMAIL_LOGOUT" "Password123!"
LOGOUT_REFRESH=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')

call POST /api/v1/auth/logout "{\"refreshToken\":\"$LOGOUT_REFRESH\"}"
expect_status "AUTH-09-01" "Logout returns 200" 200
expect_jq "AUTH-09-02" "Response reports success" '.data.success == true'
save_evidence "logout success"

call POST /api/v1/auth/logout "{\"refreshToken\":\"$LOGOUT_REFRESH\"}"
expect_status "AUTH-09-03" "Logout is idempotent" 200

call POST /api/v1/auth/refresh "{\"refreshToken\":\"$LOGOUT_REFRESH\"}"
expect_error "AUTH-09-04" "Logged out refresh token is revoked" 400 REFRESH_TOKEN_REVOKED

call POST /api/v1/auth/logout '{"refreshToken":"not-a-real-token"}'
expect_error "AUTH-09-05" "Unknown refresh token is rejected" 400 INVALID_REFRESH_TOKEN

call POST /api/v1/auth/logout '{}'
expect_error "AUTH-09-06" "Empty logout payload is rejected" 400 VAL_INVALID_INPUT

# ---------------------------------------------------------------- AUTH-10 logout all
header "AUTH-10 POST /api/v1/auth/logout-all"
EMAIL_ALL=$(new_email logoutall)
register_pending "$EMAIL_ALL"; USER_ALL="$NEW_USER_ID"
CREATED_IDS+=("$USER_ALL")
activate_user "$EMAIL_ALL"
clear_rate_limits
clear_login_state "$EMAIL_ALL"
login_user "$EMAIL_ALL" "Password123!"
ALL_TOKEN=$(printf '%s' "$BODY" | jq -r '.data.accessToken')
ALL_REFRESH_1=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')
login_user "$EMAIL_ALL" "Password123!"
ALL_REFRESH_2=$(printf '%s' "$BODY" | jq -r '.data.refreshToken')

call POST /api/v1/auth/logout-all '{}'
expect_error "AUTH-10-01" "Logout all without JWT is rejected" 401 UNAUTHORIZED

call POST /api/v1/auth/logout-all '{}' "$ALL_TOKEN"
expect_status "AUTH-10-02" "Authenticated logout all returns 200" 200
expect_jq "AUTH-10-03" "Response reports the revoked session count" '.data.countRevoked >= 2'
save_evidence "logout all success"

call POST /api/v1/auth/refresh "{\"refreshToken\":\"$ALL_REFRESH_1\"}"
expect_error "AUTH-10-04" "First session is revoked" 400 REFRESH_TOKEN_REVOKED
call POST /api/v1/auth/refresh "{\"refreshToken\":\"$ALL_REFRESH_2\"}"
expect_error "AUTH-10-05" "Second session is revoked" 400 REFRESH_TOKEN_REVOKED

# ---------------------------------------------------------------- gateway invariants
header "GATEWAY invariants"
# send a spoofed identity header explicitly
HTTP=$(curl -sS -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -X POST "$GATEWAY/api/v1/auth/login" \
    -H 'Content-Type: application/json' -H 'x-user-id: 11111111-1111-1111-1111-111111111111' \
    -d "{\"identifier\":\"$EMAIL_MAIN\",\"password\":\"NewPassword123!\"}")
BODY=$(cat "$TMP/body")
expect_error "GW-01" "Spoofed identity header is rejected" 403 FORBIDDEN_HEADER_SPOOFING

call GET /api/v1/notifications/email/otp
expect_error "GW-02" "Internal route is hidden from clients" 404 NOT_FOUND

clear_rate_limits
for _ in 1 2 3 4 5; do
    curl -sS -o /dev/null -X POST "$GATEWAY/api/v1/auth/register" -H 'Content-Type: application/json' \
        -d "{\"email\":\"qa+rate$RANDOM+$RUN_ID@nexus.local\",\"password\":\"Password123!\",\"firstName\":\"Qa\",\"lastName\":\"Tester\"}"
done
HTTP=$(curl -sS -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -X POST "$GATEWAY/api/v1/auth/register" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"qa+rate-over+$RUN_ID@nexus.local\",\"password\":\"Password123!\",\"firstName\":\"Qa\",\"lastName\":\"Tester\"}")
BODY=$(cat "$TMP/body")
expect_error "GW-03" "Register rate limit returns 429" 429 RATE_LIMIT_EXCEEDED
expect_header "GW-04" "Rate limit response exposes Retry-After" "Retry-After"
clear_rate_limits

LONG_KEY=$(printf 'a%.0s' {1..129})
HTTP=$(curl -sS -o "$TMP/body" -D "$TMP/headers" -w '%{http_code}' -X POST "$GATEWAY/api/v1/auth/login" \
    -H 'Content-Type: application/json' -H "Idempotency-Key: $LONG_KEY" \
    -d "{\"identifier\":\"$EMAIL_MAIN\",\"password\":\"NewPassword123!\"}")
BODY=$(cat "$TMP/body")
expect_error "GW-05" "Oversized Idempotency-Key is rejected" 400 VAL_INVALID_INPUT

clear_rate_limits
call POST /api/v1/auth/login "{\"identifier\":\"$EMAIL_MAIN\",\"password\":\"NewPassword123!\"}"
expect_header "GW-06" "Every response carries X-Trace-Id" "X-Trace-Id"

# ---------------------------------------------------------------- banned account checks
header "BANNED account guards"
EMAIL_BANNED=$(new_email banned)
register_pending "$EMAIL_BANNED"; USER_BANNED="$NEW_USER_ID"
CREATED_IDS+=("$USER_BANNED")
activate_user "$EMAIL_BANNED"

if [ -n "$ADMIN_TOKEN" ] && [ -n "$USER_BANNED" ]; then
    call PUT "/api/v1/admin/users/$USER_BANNED" \
        '{"status":"BANNED","reason":"QA auth e2e ban check"}' "$ADMIN_TOKEN"
    expect_status "BAN-01" "Admin can ban the test account" 200

    clear_rate_limits
    call POST /api/v1/auth/register \
        "{\"email\":\"$EMAIL_BANNED\",\"password\":\"Password123!\",\"firstName\":\"Qa\",\"lastName\":\"Tester\"}"
    expect_error "BAN-02" "Banned account cannot re-register" 403 ACCOUNT_BANNED

    clear_rate_limits
    call POST /api/v1/auth/otp/resend "{\"email\":\"$EMAIL_BANNED\"}"
    expect_error "BAN-03" "Banned account cannot resend OTP" 403 ACCOUNT_BANNED

    clear_rate_limits
    call POST /api/v1/auth/otp/verify "{\"email\":\"$EMAIL_BANNED\",\"otp\":\"123456\"}"
    expect_error "BAN-04" "Banned account cannot verify OTP" 403 ACCOUNT_BANNED

    clear_rate_limits
    clear_login_state "$EMAIL_BANNED"
    call POST /api/v1/auth/login "{\"identifier\":\"$EMAIL_BANNED\",\"password\":\"Password123!\"}"
    expect_error "BAN-05" "Banned account cannot log in" 403 ACCOUNT_BANNED
else
    fail "BAN-01" "Admin token unavailable, banned checks skipped"
fi

# ---------------------------------------------------------------- summary
header "Summary"
printf 'Passed: %d\nFailed: %d\n' "$PASSED" "$FAILED" | tee -a "$REPORT"
printf '\nEvidence file: `%s`\n' "$EVIDENCE" | tee -a "$REPORT"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
