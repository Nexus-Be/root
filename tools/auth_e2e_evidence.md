
### register success

{
  "success": true,
  "statusCode": 201,
  "message": "Operation completed successfully.",
  "data": {
    "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
    "email": "qa+main+1793411974@nexus.local",
    "otpExpiresIn": 300
  },
  "traceId": "00-816489d6b249aa7cfe73695c62474520-8a7ee488d8d6c987-00",
  "timestamp": "2026-10-31T01:59:35Z"
}

### otp verify success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "isVerified": true,
    "email": "qa+main+1793411974@nexus.local",
    "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
    "role": "buyer",
    "roles": [
      "buyer"
    ],
    "permissions": [
      "CART.VIEW",
      "CART.UPDATE",
      "ORDER.VIEW",
      "CHECKOUT.START"
    ]
  },
  "traceId": "00-1387b67e9ed1849f75c106532a22ca67-625b8ad4c05e7db2-00",
  "timestamp": "2026-10-31T01:59:36Z"
}

### otp resend success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "email": "qa+resend+1793411974@nexus.local",
    "resendCooldown": 60
  },
  "traceId": "00-da8b55cd331c40621d34b963c731e1d3-965b3e9b8529471c-00",
  "timestamp": "2026-10-31T01:59:39Z"
}

### login success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYTU1Y2Y3Zi1lMWI1LTQ0MmYtOGM5OC1kMWE4OTQ4NTA4NGQiLCJ1c2VySWQiOiJiYTU1Y2Y3Zi1lMWI1LTQ0MmYtOGM5OC1kMWE4OTQ4NTA4NGQiLCJpZCI6ImJhNTVjZjdmLWUxYjUtNDQyZi04Yzk4LWQxYTg5NDg1MDg0ZCIsImVtYWlsIjpbInFhK21haW4rMTc5MzQxMTk3NEBuZXh1cy5sb2NhbCIsInFhK21haW4rMTc5MzQxMTk3NEBuZXh1cy5sb2NhbCJdLCJuYW1lIjoiUWEgVGVzdGVyIiwianRpIjoiZDIyYzNmZmQtYzhkMS00ZmJmLWJmMTYtZGE3NmU0ODU0YTk5IiwiaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS93cy8yMDA4LzA2L2lkZW50aXR5L2NsYWltcy9yb2xlIjoiYnV5ZXIiLCJyb2xlIjoiYnV5ZXIiLCJyb2xlcyI6ImJ1eWVyIiwicGVybWlzc2lvbiI6WyJDQVJULlZJRVciLCJDQVJULlVQREFURSIsIk9SREVSLlZJRVciLCJDSEVDS09VVC5TVEFSVCJdLCJwZXJtaXNzaW9ucyI6WyJDQVJULlZJRVciLCJDQVJULlVQREFURSIsIk9SREVSLlZJRVciLCJDSEVDS09VVC5TVEFSVCJdLCJuYmYiOjE3OTM0MTE5ODAsImV4cCI6MTc5MzQxNTU4MCwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo4MDAxIiwiYXVkIjoic2hvcHBpbmdjYXJ0LWFwaSJ9.IxKpUiRlBisLMT90X10yBERG99oZPFGcNSFLJ7w6lKQ",
    "refreshToken": "Ay6EYo2C3I5Y1OELV0uLMRlPWdWJ23HJjjGbNeM7nMUduIdPRDCfJR-XOZsB9g5sAoSODyDVME2UvZ2lh6pIDA",
    "tokenType": "Bearer",
    "expiresIn": 3599,
    "user": {
      "id": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
      "email": "qa+main+1793411974@nexus.local",
      "username": null,
      "firstName": "Qa",
      "lastName": "Tester",
      "roles": [
        "buyer"
      ],
      "permissions": [
        "CART.VIEW",
        "CART.UPDATE",
        "ORDER.VIEW",
        "CHECKOUT.START"
      ],
      "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
      "role": "buyer"
    },
    "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
    "email": "qa+main+1793411974@nexus.local",
    "role": "buyer",
    "roles": [
      "buyer"
    ],
    "permissions": [
      "CART.VIEW",
      "CART.UPDATE",
      "ORDER.VIEW",
      "CHECKOUT.START"
    ]
  },
  "traceId": "00-ac7191bace470763708cbf03c74b0b0a-7a0334a451ec3c3d-00",
  "timestamp": "2026-10-31T01:59:40Z"
}

### refresh success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYTU1Y2Y3Zi1lMWI1LTQ0MmYtOGM5OC1kMWE4OTQ4NTA4NGQiLCJ1c2VySWQiOiJiYTU1Y2Y3Zi1lMWI1LTQ0MmYtOGM5OC1kMWE4OTQ4NTA4NGQiLCJpZCI6ImJhNTVjZjdmLWUxYjUtNDQyZi04Yzk4LWQxYTg5NDg1MDg0ZCIsImVtYWlsIjpbInFhK21haW4rMTc5MzQxMTk3NEBuZXh1cy5sb2NhbCIsInFhK21haW4rMTc5MzQxMTk3NEBuZXh1cy5sb2NhbCJdLCJuYW1lIjoiUWEgVGVzdGVyIiwianRpIjoiZDRhYTZmM2YtNGEzMi00ZDFhLTk5ZmYtOThiMmM3ZjhjNGRjIiwiaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS93cy8yMDA4LzA2L2lkZW50aXR5L2NsYWltcy9yb2xlIjoiYnV5ZXIiLCJyb2xlIjoiYnV5ZXIiLCJyb2xlcyI6ImJ1eWVyIiwicGVybWlzc2lvbiI6WyJDQVJULlZJRVciLCJDQVJULlVQREFURSIsIk9SREVSLlZJRVciLCJDSEVDS09VVC5TVEFSVCJdLCJwZXJtaXNzaW9ucyI6WyJDQVJULlZJRVciLCJDQVJULlVQREFURSIsIk9SREVSLlZJRVciLCJDSEVDS09VVC5TVEFSVCJdLCJuYmYiOjE3OTM0MTE5ODQsImV4cCI6MTc5MzQxNTU4NCwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo4MDAxIiwiYXVkIjoic2hvcHBpbmdjYXJ0LWFwaSJ9.MLDJMrE_4orStE38gjqt4R_wKQHOCxt-MtqhW4ih55A",
    "refreshToken": "RE0Oj2DP5HbhigxJ3XSdfA1Vqxb8yOMZRNimIze0WqEN5gJ9-imyrpfJu7OGzBndjy-wyzwIJwuvOcdywwaFmA",
    "expiresIn": 3599,
    "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
    "email": "qa+main+1793411974@nexus.local",
    "role": "buyer",
    "roles": [
      "buyer"
    ],
    "permissions": [
      "CART.VIEW",
      "CART.UPDATE",
      "ORDER.VIEW",
      "CHECKOUT.START"
    ],
    "user": {
      "id": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
      "email": "qa+main+1793411974@nexus.local",
      "username": null,
      "firstName": "Qa",
      "lastName": "Tester",
      "roles": [
        "buyer"
      ],
      "permissions": [
        "CART.VIEW",
        "CART.UPDATE",
        "ORDER.VIEW",
        "CHECKOUT.START"
      ],
      "userId": "ba55cf7f-e1b5-442f-8c98-d1a89485084d",
      "role": "buyer"
    }
  },
  "traceId": "00-61c008318796cdfeb60fae2a12410b90-c907b1cd64b03ce9-00",
  "timestamp": "2026-10-31T01:59:44Z"
}

### forgot password success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "email": "qa+main+1793411974@nexus.local"
  },
  "traceId": "00-034be152e416ecaf48061294f177b165-27f288af452126c8-00",
  "timestamp": "2026-10-31T01:59:45Z"
}

### reset password success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "success": true
  },
  "traceId": "00-079050b0e6d1a16d64a9e51d7ce31501-5308609c8dd7aa75-00",
  "timestamp": "2026-10-31T01:59:45Z"
}

### change password success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "success": true
  },
  "traceId": "00-5e12d6e508154415bb41b37531061442-3dba6a128bbd1b66-00",
  "timestamp": "2026-10-31T01:59:49Z"
}

### logout success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "success": true
  },
  "traceId": "00-c82a4ae2af54b82d4f15faecc049e68d-c24f75068ed9f0f5-00",
  "timestamp": "2026-10-31T01:59:52Z"
}

### logout all success

{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "countRevoked": 2
  },
  "traceId": "00-9c286e2e9d4bd9a55aefad69d6072d32-702ac2fcae396d7d-00",
  "timestamp": "2026-10-31T01:59:55Z"
}
