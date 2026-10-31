# ScriptTest - Bộ kiểm tra quy tắc hệ thống Nexus

Bộ script Bash chỉ-đọc (read-only) để phát hiện vi phạm các quy tắc bất biến của Nexus
trong `src/Services/**`. Không build, không sửa code, không đụng database.

## Chạy nhanh

```bash
bash src/ScriptTest/run-all.sh                    # chỉ fail khi có vi phạm MỚI
bash src/ScriptTest/run-all.sh --strict           # fail cả cảnh báo mới
bash src/ScriptTest/run-all.sh --service User     # chỉ quét một service
bash src/ScriptTest/run-all.sh --json             # tổng hợp dạng JSON cho CI
bash src/ScriptTest/run-all.sh --ci               # annotation cho GitHub Actions
bash src/ScriptTest/run-all.sh --update-baseline  # chốt lại baseline sau khi sửa
```

Chạy riêng từng checker khi cần debug:

```bash
bash src/ScriptTest/checks/10-enum.sh
bash src/ScriptTest/checks/20-error-codes.sh
bash src/ScriptTest/checks/30-error-messages.sh
bash src/ScriptTest/checks/40-routes.sh
bash src/ScriptTest/checks/50-architecture.sh
bash src/ScriptTest/checks/60-database.sh
bash src/ScriptTest/checks/70-gateway.sh
```

Exit code: `0` sạch, `1` có vi phạm mới, `2` sai tham số hoặc sai tên service.

## Baseline ratchet

`baseline/violations.txt` là snapshot vi phạm đã biết. Mỗi dòng là một fingerprint
`SEVERITY<TAB>RULE_ID<TAB>đường/dẫn/tương/đối`, **không chứa số dòng**, nên sửa code
không làm hỏng baseline.

Luồng chạy:

1. Quét toàn bộ, ghi fingerprint hiện tại.
2. So với baseline bằng `comm -13`.
3. Vi phạm mới có `ERROR` thì exit `1`; `WARN` mới chỉ in ra, trừ khi `--strict`.
4. Vi phạm cũ đã sửa được báo là "không còn tái hiện"; chạy `--update-baseline` để chốt.

Nhờ vậy có thể bật script trong CI ngay cả khi codebase còn vi phạm cũ.

## Cấu trúc

```
src/ScriptTest/
├── run-all.sh                  # entrypoint + baseline ratchet
├── RULES.md                    # danh mục mã rule và nguồn spec
├── baseline/violations.txt     # snapshot vi phạm đã biết
├── lib/
│   ├── common.sh               # record(), find_cs(), grep_cs(), split_hit()
│   ├── csharp.sh               # bóc comment, trích route/enum/message
│   ├── strip_comments.awk
│   ├── strip_literals.awk
│   └── exception_literals.awk
└── checks/                     # 7 checker độc lập
```

## Nguyên tắc khi thêm rule

1. Rule mới phải có mã trong `RULES.md` theo đúng tiền tố nhóm (`ENUM`, `ERRC`, `ERRS`,
   `ROUTE`, `ARCH`, `DB`, `GW`) và ghi rõ nguồn spec.
2. Dùng `record ERROR|WARN <RULE_ID> <file> <line> "<message>"`. Message của script
   viết bằng tiếng Anh, sentence case, để đồng bộ với thông báo lỗi hệ thống.
3. `ERROR` chỉ dành cho bất biến không thể thương lượng (đã ghi trong `AGENTS.md` hoặc
   `specs/06`). Suy luận heuristic phải là `WARN`.
4. Trước khi grep cấu trúc, dùng `strip_literals` (hoặc `grep_cs_code`) để tránh khớp
   nhầm trong comment và string.
5. Kiểm tra lại trên một fixture tạm trong `/tmp` trước khi chốt baseline.

## Giới hạn đã biết

- Đây là phân tích tĩnh bằng regex, không phải Roslyn. Các rule mang tính ngữ nghĩa
  (ví dụ enum trả về đúng kiểu trong DTO) chỉ dừng ở mức heuristic `WARN`.
- `ENUM-007` chỉ nhìn thấy property `int` có tên kết thúc bằng `Status/Type/State/Role`.
- `ROUTE-007` chỉ kiểm tra sự hiện diện của `GetUserId()` / `HasRole()` / `RequireRole`.
- Script không kiểm tra runtime; hợp đồng biên của Gateway vẫn do
  `Gateway.Tests/ArchitecturalContractInvariantTests.cs` bảo vệ.
