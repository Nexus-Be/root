# QUY CHUẨN ĐÓNG PHIÊN, BÁO CÁO & LƯU TRỮ KẾ HOẠCH (.AGENTS/PLAN VÀ .AGENTS/HISTORY)

> **BẮT BUỘC ĐỌC ĐẦU VÀ CUỐI MỖI PHIÊN LÀM VIỆC**: Quy tắc này áp dụng cho toàn bộ AI Coding Agents mỗi khi kết thúc một nhiệm vụ được giao, kết thúc phiên làm việc, hoặc khi có lệnh hoãn/tạm dừng.

## 1. Quy chuẩn Lưu trữ Kế hoạch Chuẩn tại `.agents/plan/`
- **Thời điểm ghi**: Khi một kế hoạch được chốt sau thảo luận dài, hoặc khi hoàn thành một chuỗi công việc được giao (không phải nháp ban đầu của Planner, mà là bản kế hoạch chuẩn cuối cùng làm nguồn sự thật).
- **Mã Plan (ID)**: Bắt buộc chứa mốc thời gian tạo và mục tiêu giải quyết. Định dạng: `PLAN-YYYYMMDD-HHMM-[TEN_VAN_DE].md` (ví dụ: `PLAN-20261026-0200-API-GATEWAY-MOCK.md`).
- **Nội dung bắt buộc trong file Plan**:
  1. **Mã Plan (ID)** & Thời gian khởi tạo/chốt.
  2. **Vấn đề cần giải quyết**: Mô tả vấn đề tổng thể mà người dùng đưa ra.
  3. **Hướng giải quyết**: Kiến trúc và phương án kỹ thuật đã thống nhất.
  4. **Danh mục Task & Checklist**: Chia nhỏ thành các task con rõ ràng, có trạng thái checklist `[x]` (đã xong) và `[ ]` (chưa xong).

## 2. Quy chuẩn Báo cáo Nhật ký tại `.agents/history/`
Mỗi lần kết thúc/hoãn phiên, bắt buộc tạo file nhật ký theo ngày: `.agents/history/YYYY-MM-DD_session_summary.md` gồm 5 phần:
1. **Miêu tả tổng thể công việc**: Tóm tắt phạm vi công việc đã thực hiện trong phiên/prompt.
2. **Phân tích & Nghiên cứu**: Lý do kỹ thuật, nguyên nhân gốc rễ, đối chiếu tài liệu và kiến trúc.
3. **Liên kết Kế hoạch**: Bắt buộc trỏ tới Mã Plan (`PLAN-ID`) tương ứng trong `.agents/plan/` (dù đang làm dở hay đã hoàn thành).
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
