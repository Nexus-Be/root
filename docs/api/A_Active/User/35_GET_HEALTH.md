# [GET] /health

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Health`  
> **Mã tham chiếu Excel:** `35`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Kiểm tra tình trạng hoạt động của UserService (phục vụ container orchestration và health probes).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/health`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Controller Action / Endpoint:** `User.Api/Program.cs` $\rightarrow$ `MapGet("/health")`
* **Thực thể & Bảng DB:** N/A (In-memory probe)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

* Không yêu cầu tham số đầu vào hay xác thực.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ
```json
{
  "status": "Healthy",
  "service": "user-service"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `503 ServiceUnavailable` | `SERVICE_UNAVAILABLE` | `"Service health probe failed."` | Dịch vụ gặp sự cố không thể xử lý yêu cầu |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Status: COMPLETED
