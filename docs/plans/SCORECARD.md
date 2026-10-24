# SCORECARD — Hệ thống Nexus-Be (audit 2026-10-24)

**Nguồn:** 9 gate tự động (`.tools/audit`) + 9 báo cáo repo + 6 báo cáo root + build/test thật.
**Thang điểm:** 0 = không có · 1 = chỉ có vỏ · 2 = có nhưng đứt · 3 = dùng được một phần · 4 = tốt · 5 = mẫu mực.
**Cột C1–C8** ánh xạ 8 mục tiêu của bạn:
C1 mỗi phần 1 việc · C2 dễ sửa/ít phụ thuộc · C3 file & liên kết đồng nhất · C4 test/kiểm thử độc lập · C5 theo dõi request · C6 doc là sự thật · C7 luật đúng & tuân thủ · C8 format đồng nhất.

## 1. Bảng điểm

| Repo | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | TB |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **ApiGateway** | 4 | 4 | 4 | 4 | 5 | 3 | 3 | 4 | **3.9** |
| **Wallet** | 5 | 4 | 4 | 2 | 4 | 3 | 2 | 4 | **3.5** |
| **Log** | 5 | 4 | 4 | 2 | 4 | 3 | 2 | 4 | **3.5** |
| **User** | 4 | 4 | 4 | 4 | 2 | 3 | 3 | 4 | **3.5** |
| **Notification** | 3 | 4 | 3 | 2 | 1 | 3 | 3 | 3 | **2.8** |
| **Catalog** | 3 | 3 | 4 | 1 | 1 | 1 | 3 | 3 | **2.4** |
| **Commerce** | 1 | 3 | 4 | 1 | 1 | 1 | 3 | 3 | **2.1** |
| **Fulfillment** | 2 | 3 | 4 | 0 | 0 | 1 | 3 | 3 | **2.0** |
| **Auction** | 2 | 3 | 4 | 0 | 0 | 1 | 3 | 3 | **2.0** |
| **Root (hệ thống)** | 3 | 4 | 3 | 2 | 3 | 2 | 2 | 2 | **2.6** |

**Trung bình hệ thống: 2.7 / 5** — “khung tốt, ruột chưa nối”.

## 2. Điểm mạnh thật (không phải khen suông)

| # | Điều đã đúng | Bằng chứng |
|---|---|---|
| 1 | **Build 100%**: 9/9 solution `Release` EXIT 0 | `logs/build-all.log` |
| 2 | **Không Repository pattern** — 0 hit toàn hệ | gate `deps` |
| 3 | **Không phụ thuộc chéo service** — 0 project ref ra ngoài, 0 connection string của service khác | gate `deps` |
| 4 | **Inward-only** — 0 link trỏ ngược ra root/sibling trong 9 repo | gate `doclink` |
| 5 | **Port/DB/compose khớp spec 100%** ở tầng Dockerfile/compose/env | gate `port` (phần Docker) |
| 6 | **Mock Engine Gateway** là tài sản thật: đổi `Mock/Real` bằng `gateway.runtime.json`, không sửa code | `gateway.runtime.json` + `ModeEvaluator` |
| 7 | **Luồng event OTP chạy thật**: User publish → Notification consume (namespace + record khớp) | `AuthService.cs:147` ↔ `SendOtpEmailConsumer.cs:9` |
| 8 | **Envelope lỗi chuẩn hoá tốt**: `ApiResponse<T>` / `ApiErrorResponse` + mã SCREAMING_SNAKE | `Responses/`, gate `errmsg` |
| 9 | **3 service CQRS/vertical-slice sạch** (Wallet, Log) — mẫu để nhân ra | `Application/Features` |

## 3. Bảng “mục tiêu của bạn đã đạt chưa?”

| Mục tiêu bạn nêu | Đạt? | Con số | Nút thắt lớn nhất |
|---|:---:|---|---|
| Dễ dev, mỗi phần 1 việc, rõ ràng | ❌ **40%** | 9/9 có 4 tầng, nhưng 11/15 controller Gateway rỗng; Application layer 5 service chỉ 104–204 LOC | Không có bề mặt để “dev một tính năng” end-to-end |
| Dễ sửa, ít phụ thuộc | ✅ **80%** | 0 ref chéo, 0 DB chéo, 0 Repository pattern | Service class gộp nhiều use case (Auction/Commerce/Catalog/Fulfillment) |
| File đúng folder, liên kết đồng nhất | ❌ **50%** | 0 outward link ✅; nhưng proto 4 bản/3 hash, event 1 contract 2 bản, dbml 1 bảng thừa | Không có nguồn sự thật chung cho proto/event |
| Test độc lập REST/gRPC/event/function | ❌ **25%** | 3/9 repo có test; gRPC server 3/8; 5 service 0 bề mặt; 1/1 event chạy được | 5 service chưa có endpoint nào để test |
| Theo dõi request từ client | ⚠️ **45%** | Gateway trace + propagate 6 header ✅; chỉ 3/8 service export OTel; `x-trace-id` tới 6 service không có ai ghi nhận | 6 service không có OTel |
| Doc đúng chỗ, đúng context, là sự thật | ⚠️ **55%** | Vị trí ✅ (0 lạc biên giới); `specs/01` ✅; nhưng `specs/02/04` mô tả hệ chưa có; 3 guide dạy việc không làm được | specs mô tả “to-be” như “as-is” |
| Luật đúng | ⚠️ **60%** | 6 nguyên tắc hợp lý, 0 mâu thuẫn; nhưng 3 bản luật, 0 cưỡng chế, 3 luật bị vi phạm | Không có gate trong CI |
| Format đồng nhất | ❌ **50%** | Dockerfile/`.gitignore`/CI giống nhau ✅; Application layer **3 style**, 13 file BOM, có/không `nuget.config` | Thiếu `Directory.Build.props` + `.editorconfig` |

## 4. “Hệ thống có hoạt động ổn không?”

| Khả năng | Trạng thái | Chi tiết |
|---|:---:|---|
| Build toàn hệ | ✅ | 9/9 EXIT 0 |
| Unit test | ⚠️ | 3/9 repo, 73 `[Fact]` tổng (Gateway 62, User 9, Notification 2) |
| Chạy 1 service độc lập | ✅ | Dockerfile + compose per-service + DB riêng |
| Gọi REST qua Gateway | ⚠️ | 16 action thật / 15 controller; 11 controller rỗng |
| Gọi gRPC trực tiếp | ⚠️ | 3/8 service có server (User 4/6 rpc, Wallet 5/5, Log 4/4) |
| Event bus | ❌ | 1 luồng thật (OTP); 6/8 event trong registry không tồn tại |
| Trace end-to-end | ⚠️ | Gateway → 3 service; 6 service không export |
| Tái lập từ git | ❌ | 9/9 dirty; migration regenerated chưa commit; submodule không ghim branch |

## 5. Top 10 việc đáng làm nhất (theo đòn bẩy)

1. **Chốt nguồn sự thật proto** + script sync (gỡ bế tắc cho cả 8 service).
2. **Commit migration** (nếu không, mọi thứ khác đều trên nền không tái lập).
3. **Nối Catalog end-to-end** (gRPC 4 rpc + 4 action Gateway + 6 test + OTel) làm **khuôn mẫu**.
4. **Sửa `launchSettings.json`** 6 service (15 phút, xoá 6 vi phạm luật).
5. **Bật OTel + propagate trace cho 6 service** (mở khoá “theo dõi request”).
6. **Thêm endpoint `POST /api/v1/log/batch`** hoặc chuyển sang RabbitMQ (gỡ 404 âm thầm).
7. **Sửa 19 lỗi tiếng Việt** (luật §5).
8. **Dựng CI thật**: trigger `dev`/`mock` + `dotnet build/test` + 9 gate.
9. **Tạo `Directory.Build.props` + `.editorconfig`** ở root, hết drift format.
10. **Đồng bộ `specs/02/04`** về đúng hiện trạng + cột `Status`.
