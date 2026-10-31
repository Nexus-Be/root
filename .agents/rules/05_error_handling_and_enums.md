# 05 — ERROR HANDLING MATRIX, SENTENCE CASE & ENUM BOUNDARY RULES

## 1. 100% English Language Invariant
* All error messages, exception details, problem details, validation failures, and response payloads must strictly be written in English.
* Vietnamese error strings are strictly prohibited in runtime client-facing responses and exceptions.

## 2. Sentence Case for Error Messages
* Capitalize ONLY the first letter of the message sentence.
* Subsequent words must be lowercase, except for technical acronyms or identifiers (`ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`, `API`, `HTTP`).
* Examples:
  * Correct: `"Wallet account not found for the specified user."`
  * Correct: `"Insufficient balance to complete the transaction."`
  * Correct: `"Email is already registered in the system."`
  * Incorrect: `"Số dư không đủ"` (Vietnamese prohibited)
  * Incorrect: `"wallet not found"` (First letter must be uppercase)
  * Incorrect: `"WALLET NOT FOUND"` (All-caps prohibited for message text)
  * Incorrect: `"Wallet Not Found Provided"` (Title Case prohibited)

## 3. SCREAMING_SNAKE_CASE for Error Codes
* Error codes must always be uppercase with underscores separating words (`SCREAMING_SNAKE_CASE`).
* Prohibit arbitrary `ERR_` prefixes (e.g. use `INVALID_CREDENTIALS`, not `ERR_INVALID_CREDENTIALS`; use `SOD_VIOLATION`, not `ERR_SOD_VIOLATION`).
* Validation error codes use `VAL_` prefix (e.g. `VAL_INVALID_INPUT`, `VAL_INVALID_USER_ID`, `VAL_INVALID_EMAIL`, `VAL_INVALID_ARGUMENT`).
* Examples:
  * Correct: `WALLET_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `OTP_INVALID`, `VAL_INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`
  * Incorrect: `ERR_WALLET_NOT_FOUND`, `wallet_not_found`, `WalletNotFound`

## 4. RFC 9110 ProblemDetails Envelope
* Microservice controllers and `GlobalExceptionHandlerMiddleware` return errors conforming to RFC 9110:
  ```json
  {
    "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
    "title": "Not found",
    "status": 404,
    "errorCode": "USER_NOT_FOUND",
    "detail": "User account not found for the specified identifier.",
    "message": "User account not found for the specified identifier.",
    "traceId": "0HNPGT7G285Q2"
  }
  ```

## 5. Enum Serialization Boundary Rule
* **Inside Database (PostgreSQL)**: 100% of Enums must be stored as signed 32-bit `integer` (int32). Prohibit `HasConversion<string>()` and custom Postgres enum types.
* **Inside Domain & Service Layer**: 100% strongly typed C# enums backed by `int32`, initialized with explicit zero value. Prohibit magic numbers or raw strings.
* **Outbound REST API (to Client)**: 100% serialized as `PascalCase` strings (`"Active"`, `"PendingVerification"`, `"Delivered"`, `"Payment"`). Never serialize or document Enums as raw integers or all-caps SCREAMING_SNAKE_CASE in JSON responses (prohibited: `"status": "ACTIVE"`, `"status": 1`).
* **Inbound REST API (from Client)**:
  * JSON Body: Accept string values via `PascalCaseJsonStringEnumConverter` (case-insensitive and SCREAMING_SNAKE_CASE supported). Prohibit raw integer input (`allowIntegerValues: false`).
  * Query/Route: Parse safely via `EnumExtensions.TryToEnum<TEnum>()`.
