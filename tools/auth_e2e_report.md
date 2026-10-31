
## Auth E2E through Gateway - 2026-10-31T01:59:34Z
Gateway `http://localhost:8080`, run `1793411974`.

## AUTH-01 POST /api/v1/auth/register
PASS  AUTH-01-01     New account returns 201
PASS  AUTH-01-02     Envelope has userId, email and otpExpiresIn=300
PASS  AUTH-01-03     OTP is stored in Redis
PASS  AUTH-01-04     Invalid email
PASS  AUTH-01-05     Password shorter than 8 characters
PASS  AUTH-01-06     Active email is rejected

## AUTH-02 POST /api/v1/auth/otp/verify
PASS  AUTH-02-01     Valid OTP activates the account
PASS  AUTH-02-02     Response reports isVerified and buyer role
PASS  AUTH-02-03     Wrong OTP is rejected
PASS  AUTH-02-04     Reusing a consumed OTP is rejected
PASS  AUTH-02-05     Expired OTP is rejected
PASS  AUTH-02-06     Unknown account is rejected

## AUTH-03 POST /api/v1/auth/otp/resend
PASS  AUTH-03-01     Resend returns 200
PASS  AUTH-03-02     Response advertises a 60 second cooldown
PASS  AUTH-03-03     Resend rotates the OTP
PASS  AUTH-03-04     Verified account cannot resend
PASS  AUTH-03-05     Unknown account cannot resend

## AUTH-04 POST /api/v1/auth/login
PASS  AUTH-04-01     Valid credentials return 200
PASS  AUTH-04-02     Tokens and user profile are returned
PASS  AUTH-04-03     Wrong password is rejected
PASS  AUTH-04-04     Pending account cannot log in
PASS  AUTH-04-05     Fifth failed attempt locks the account
PASS  AUTH-04-06     Seed admin can log in

## AUTH-05 POST /api/v1/auth/refresh
PASS  AUTH-05-01     Refresh rotates the session
PASS  AUTH-05-02     New access and refresh tokens are returned
PASS  AUTH-05-03     Old refresh token is rejected
PASS  AUTH-05-04     Unknown refresh token is rejected
PASS  AUTH-05-05     Missing refresh token is rejected

## AUTH-06 POST /api/v1/auth/password/forgot
PASS  AUTH-06-01     Forgot password returns 200
PASS  AUTH-06-02     Generic response contains the email
PASS  AUTH-06-03     Password reset OTP is stored
PASS  AUTH-06-04     Unknown email still returns generic 200
PASS  AUTH-06-05     No OTP is created for unknown email
PASS  AUTH-06-06     Invalid email format is rejected

## AUTH-07 PUT /api/v1/auth/password/reset
PASS  AUTH-07-01     Valid reset OTP changes the password
PASS  AUTH-07-02     Response reports success
PASS  AUTH-07-03     Old password no longer works
PASS  AUTH-07-04     New password works
PASS  AUTH-07-05     Reusing reset OTP is rejected
PASS  AUTH-07-06     Wrong reset OTP is rejected
PASS  AUTH-07-07     Password confirmation mismatch is rejected
PASS  AUTH-07-08     Short reset password is rejected

## AUTH-08 PATCH /api/v1/auth/password
PASS  AUTH-08-01     Change password without JWT is rejected
PASS  AUTH-08-02     Authenticated change password returns 200
PASS  AUTH-08-03     Response reports success
PASS  AUTH-08-04     Change password revokes existing refresh tokens
PASS  AUTH-08-05     Wrong old password is rejected
PASS  AUTH-08-06     Reusing the current password is rejected

## AUTH-09 POST /api/v1/auth/logout
PASS  AUTH-09-01     Logout returns 200
PASS  AUTH-09-02     Response reports success
PASS  AUTH-09-03     Logout is idempotent
PASS  AUTH-09-04     Logged out refresh token is revoked
PASS  AUTH-09-05     Unknown refresh token is rejected
PASS  AUTH-09-06     Empty logout payload is rejected

## AUTH-10 POST /api/v1/auth/logout-all
PASS  AUTH-10-01     Logout all without JWT is rejected
PASS  AUTH-10-02     Authenticated logout all returns 200
PASS  AUTH-10-03     Response reports the revoked session count
PASS  AUTH-10-04     First session is revoked
PASS  AUTH-10-05     Second session is revoked

## GATEWAY invariants
PASS  GW-01          Spoofed identity header is rejected
PASS  GW-02          Internal route is hidden from clients
PASS  GW-03          Register rate limit returns 429
PASS  GW-04          Rate limit response exposes Retry-After
PASS  GW-05          Oversized Idempotency-Key is rejected
PASS  GW-06          Every response carries X-Trace-Id

## BANNED account guards
PASS  BAN-01         Admin can ban the test account
PASS  BAN-02         Banned account cannot re-register
PASS  BAN-03         Banned account cannot resend OTP
PASS  BAN-04         Banned account cannot verify OTP
PASS  BAN-05         Banned account cannot log in

## Summary
Passed: 70
Failed: 0

Evidence file: `tools/auth_e2e_evidence.md`
