# QUY CHUẨN LƯU TRỮ KẾ HOẠCH, GHI CHÚ, XÁC NHẬN & TÀI LIỆU (.AGENTS/PLANS, NOTES, DECISIONS, DOCS)

> **BẮT BUỘC ĐỌC ĐẦU VÀ CUỐI MỖI PHIÊN LÀM VIỆC**: Quy tắc này áp dụng cho toàn bộ AI Coding Agents mỗi khi lập kế hoạch, ghi chú vận hành, xác nhận quyết định hoặc viết tài liệu cho người đọc.

## 1. Quy chuẩn Lưu trữ Kế hoạch Chuẩn tại `.agents/plans/`
- **Thời điểm ghi**: Lập trước khi sửa đổi mã nguồn, tạo migration hoặc thay đổi cấu hình (Plan-First Rule).
- **Định dạng tên file**: Bắt buộc lưu tại `.agents/plans/YYYY-MM-DD_HHmm-plan-<slug>.md` (ví dụ: `2026-11-29_0135-plan-yuikit-workspace-rules-and-cleanup.md`). Tuyệt đối không dùng thư mục `.agents/plan/` số ít.
- **Nội dung bắt buộc trong file Plan**:
  1. **Thời gian lập / cập nhật gần nhất**.
  2. **Mục tiêu & Vấn đề cần giải quyết**: Mô tả vấn đề tổng thể mà người dùng đưa ra.
  3. **Hướng giải quyết & Phạm vi ảnh hưởng**: Kiến trúc, Impact Analysis và phương án kỹ thuật đã thống nhất.
  4. **Danh mục Task & Checklist**: Chia nhỏ thành các task con rõ ràng, có trạng thái checklist `[x]` (đã xong) và `[ ]` (chưa xong).

## 2. Quy chuẩn Ghi chú, Xác nhận & Tài liệu Người đọc
- **Ghi chú theo Chủ đề (`.agents/notes/YYYY-MM-DD_HHmm-<topic-slug>.md`)**: Ghi nhận thao tác, vấn đề gặp phải & cách xử lý giải quyết, hoặc lưu ý đọc lại sau. Mỗi file note là 1 chủ đề duy nhất; khi đổi sang chủ đề mới (ví dụ từ mail sang giao hàng) phải tạo file note mới.
- **Xác nhận với Người dùng (`.agents/decisions/YYYY-MM-DD_HHmm-<decision-slug>.md`)**: Mọi vấn đề Agent hỏi người dùng để xác nhận hoặc chốt phương án phải lưu tại `.agents/decisions/`.
- **Tài liệu cho Người đọc (`.agents/docs/<slug>.md`)**: Khi người dùng yêu cầu viết tài liệu cho người đọc, bắt buộc chạy skill `humanizer` trước khi xuất bản và lưu tại `.agents/docs/`.

## 3. Quy chuẩn Báo cáo Nhật ký tại `.agents/history/`
Mỗi lần kết thúc/hoãn phiên, tạo file nhật ký theo ngày: `.agents/history/YYYY-MM-DD_session_summary.md` gồm 5 phần:
1. **Miêu tả tổng thể công việc**: Tóm tắt phạm vi công việc đã thực hiện trong phiên/prompt.
2. **Phân tích & Nghiên cứu**: Lý do kỹ thuật, nguyên nhân gốc rễ, đối chiếu tài liệu và kiến trúc.
3. **Liên kết Kế hoạch**: Trỏ tới file Plan tương ứng trong `.agents/plans/`.
4. **Báo cáo Cá nhân từng Thành viên**:
   - Ghi rõ: `Tên (Role/Chức vụ)`.
   - Các vấn đề đã làm trong ngày/prompt.
   - Vấn đề gặp phải & Cách giải quyết.
   - Các vấn đề chưa làm xong & Việc cần làm tiếp theo.
5. **Báo cáo Tổng thể Toàn Team**:
   - Vấn đề tổng thể sếp giao cho team.
   - Các vấn đề đã xử lý thành công.
   - Các vấn đề gặp phải và cách giải quyết của team.
   - Các phần việc/plan chưa xong, cần hoàn thành trong phiên kế tiếp.
