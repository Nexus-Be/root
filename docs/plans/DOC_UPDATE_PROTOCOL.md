# GIAO THỨC CẬP NHẬT TÀI LIỆU — 2026-10-24

Mục tiêu: mọi file `.md` trong repo phải **mô tả đúng hệ thống đang có**, không mô tả hệ thống mong muốn mà không nói rõ đó là đặc tả tương lai.

Nguyên tắc gốc: **code là sự thật**. Tài liệu chỉ được ghi điều đã kiểm chứng được bằng `file.cs:số_dòng`.

---

## 1. BA NHÃN BẮT BUỘC

Mỗi tuyên bố kỹ thuật (rpc, endpoint, event, bảng, port, package) phải mang đúng một nhãn:

| Nhãn | Nghĩa | Điều kiện dùng |
|---|---|---|
| ✅ CÓ | Đã tồn tại trong code và chạy được | Chỉ ra được `file.cs:số_dòng` + đăng ký DI/mapping |
| ⚠️ MỘT PHẦN | Có khung nhưng thiếu phần lõi | Nêu rõ thiếu gì, ở đâu |
| ❌ CHƯA CÓ | Chỉ là đặc tả mục tiêu | Nêu rõ "đặc tả mục tiêu, chưa triển khai" |

**Cấm** dùng từ khẳng định ("hệ thống hỗ trợ", "service cung cấp") cho thứ chưa có. Phải viết: "Đặc tả mục tiêu (chưa triển khai): …".

---

## 2. BANNER ĐẦU FILE

Mọi file spec/README được sửa phải có banner ngay dưới tiêu đề `#`:

```markdown
> **Trạng thái triển khai (2026-10-24):** ⚠️ Một phần — 2/5 rpc đã có trong code, 3 rpc còn là đặc tả.
> **Nguồn sự thật:** code trong repo này. Báo cáo kiểm chứng: `docs/plans/audit/{Repo}_AUDIT.md`.
> **Cập nhật lần cuối:** 2026-10-24.
```

Banner phải nêu **con số thật** (x/y), không nói chung chung.

---

## 3. BẢNG PHẢI CÓ CỘT TRẠNG THÁI

Mọi bảng liệt kê rpc / endpoint / event / bảng DB phải thêm cột cuối `Trạng thái` với ✅ / ⚠️ / ❌ và cột `Bằng chứng` (đường dẫn `file:line`) khi có.

Danh sách rpc/event **không tồn tại** thì giữ lại nhưng đánh dấu ❌ và thêm ghi chú: "chưa có trong code, xem `FIX_BACKLOG.md` mục …". Không được xoá im lặng — người đọc cần biết đặc tả gốc.

---

## 4. SỬA SỰ THẬT SAI (bắt buộc, không chỉ thêm nhãn)

Các loại lỗi sau phải sửa thẳng, không được để nguyên:

1. **Đường dẫn file không tồn tại** (`Contracts/shop.proto`, `*GrpcService.cs`, `./.tools/dotnet-ef`) → sửa thành file thật, hoặc ghi rõ "❌ không tồn tại".
2. **Port sai** → ghi cả hai: port đặc tả (Docker) và port chạy local thật từ `Properties/launchSettings.json`.
3. **Version package sai** (MassTransit 8.4.1 vs 8.3.0) → lấy đúng từ `*.csproj`.
4. **Số lượng sai** (số entity, số bảng, số rpc, số event, số configuration) → đếm lại từ code, ghi con số đúng.
5. **Tên class/enum không tồn tại** → thay bằng tên thật.
6. **Tên file solution sai** (`XxxService.sln` vs `Xxx.sln`) → sửa theo `ls`.
7. **Hứa endpoint không có** (`POST /api/v1/log/batch`, `/weatherforecast`) → đánh dấu ❌ + ghi chú.

---

## 5. GIỚI HẠN PHẠM VI

- **Chỉ sửa file `.md`.** Không sửa `.cs`, `.csproj`, `.json`, `.yml`, `.proto`, `.env`.
- Không tạo spec mới ngoài bộ 7 file `specs/` + `README.md` + `AGENTS.md`/`CLAUDE.md`.
- Không xoá nội dung thiết kế (vì nó là target). Chỉ gắn nhãn + sửa sự thật sai.
- `AGENTS.md` và `CLAUDE.md` phải **giống hệt nhau** sau khi sửa (nếu sửa một file, chép y nguyên sang file kia).
- Viết tiếng Việt, giữ nguyên cấu trúc heading hiện có (thêm mục, không đổi số thứ tự heading cũ).
- Không chạy `dotnet build`/`dotnet test`.

---

## 6. ĐỊNH NGHĨA "XONG"

- [ ] Mọi tuyên bố về rpc/endpoint/event/bảng/port/package đều có nhãn đúng.
- [ ] Không còn đường dẫn file ma, port ma, version ma trong file đã sửa.
- [ ] Banner đầu file có con số thật.
- [ ] `git diff --stat` chỉ chứa `.md`.
- [ ] Báo cáo lại: file đã sửa + 3–5 dòng "đã sửa gì".
