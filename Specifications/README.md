> **Cập nhật14/10/2026:** hướngCPU đãhủy. UI hiện tại tựápdụngSW/KEY1;KEY2unused;KEY3báocáobit;LEDG=STATUS,LEDR=EXT. Các mô tảApply/Resume bên dưới là lịch sử; dùng [hợp đồng hiện hành](13_RTL_MASTER_AUTO_CONTROL.md).

# UART APB trên DE2-115 — hồ sơ thiết kế v0.1

Ngày lập: **11/10/2026**. Mục tiêu: **ngày thứ 5 có demo echo và cấu hình bằng KEY/SW/HEX trên DE2-115**, đồng thời có hợp đồng thiết kế đủ rõ để viết RTL và testbench.

**Trạng thái cập nhật 12/10/2026:** đã có RTL Verilog-2001 và năm testbench. [Specification tổng thể](02_SYSTEM_SPEC.md) đã đối chiếu source hiện hành; [testplan chi tiết](../RTL/tb/TESTPLAN.md) phân biệt case đã có và phần cần bổ sung. Kết quả chạy trước nằm trong [verification results](../RTL/VERIFICATION_RESULTS.md); không có lượt mô phỏng/synthesis mới trong lần viết specification này. Chưa xác nhận demo vật lý. Workbook v0.1 là snapshot cũ, không dùng để chốt interface mới nhất.

**Bản draw.io hiện tại:** APB datapath còn decoder kèm guard, register bank và mux kèm status. Bỏ ERROR/W1C tại 0x018 và các event interface chỉ phục vụ nó; vẫn giữ slot parity/framing metadata, kiểm tra APB và Apply an toàn. XML và Markdown đã cập nhật; workbook v0.1 là snapshot trước thay đổi này.

## Đọc theo thứ tự

| Tài liệu | Dùng để làm gì |
|---|---|
| [01_PLAN_5_NGAY.md](01_PLAN_5_NGAY.md) | Lịch 40 giờ, đường găng, gate mỗi ngày, phạm vi dự phòng |
| [02_SYSTEM_SPEC.md](02_SYSTEM_SPEC.md) | Phạm vi, cấu hình, giao diện, hành vi quan sát được |
| [03_REGISTER_MAP.md](03_REGISTER_MAP.md) | Thanh ghi, bit, reset, side effect, lỗi và ưu tiên sự kiện |
| [04_MICROARCHITECTURE.md](04_MICROARCHITECTURE.md) | Thuật toán, datapath/control, bộ đếm và FSM từng khối |
| [05_VERIFICATION_PLAN.md](05_VERIFICATION_PLAN.md) | BFM, model độc lập, scoreboard, coverage và acceptance |
| [06_BOARD_RTL_PC_GUIDE.md](06_BOARD_RTL_PC_GUIDE.md) | Board, cáp, clock/pin, BOARD_CONTROLS, RTL master và thao tác demo |
| [07_APP_PROTOCOL.md](07_APP_PROTOCOL.md) | Phần mở rộng lưu RAM và PC yêu cầu đọc lại |
| [08_HANDOFF_CHECKLIST.md](08_HANDOFF_CHECKLIST.md) | Danh sách file cần viết, checklist trước RTL và trước bàn giao |
| [09_DECISIONS_AND_SOURCES.md](09_DECISIONS_AND_SOURCES.md) | Mâu thuẫn nguồn, quyết định đề xuất, nguồn tham khảo |
| [10_INTERFACE_CONTRACTS.md](10_INTERFACE_CONTRACTS.md) | Cổng từng khối theo draw.io mới: Input/Output, bit, khối kết nối, ý nghĩa và timing; waveform UART/APB |
| [11_FSM_TABLES.md](11_FSM_TABLES.md) | Bảng state/input/output/next state, TX ×1/RX ×16 và các khối gộp |
| [12_APB_MASTER_FLOWCHART.md](12_APB_MASTER_FLOWCHART.md) | Flowchart echo RTL, APB transaction engine và Apply/Resume; state và register cần giữ |
| [UART_SPECIFICATION.xlsx](UART_SPECIFICATION.xlsx) | Workbook để review/filter requirements, registers, ports, tests, lịch và baud |
| [diagrams/index.html](diagrams/index.html) | Xem toàn bộ sơ đồ vector đã render, có đường dẫn tới mã DOT |
| Ma trận 216 cấu hình | Đã có vòng kiểm tra trong source testbench: 9 baud × 24 frame. Xem TESTPLAN và log của đúng revision khi đánh giá PASS |

## Kiến trúc đã chọn cho đường găng

![Kiến trúc hệ thống](./diagrams/01_system.png)

- UART IP: APB slave, bank thanh ghi, TX/RX độc lập, tick phân số TX ×1/RX ×16, RX slot một byte, RTS/CTS tự động.
- Demo cơ sở: PC gửi một dữ liệu, host trên FPGA đọc RX_DATA rồi ghi TX_DATA/START, PC nhận echo. Không nối tắt TX với RX.
- Board chạy một clock 50 MHz: UART/APB cùng dùng `clk`. Đây là **profile cụ thể**, không phải chứng nhận hỗ trợ hai clock lệch pha.
- `BOARD_CONTROLS` nhận KEY/SW, xuất pending config và xung Apply/Resume. `APB_ECHO_MASTER_FSM` là master RTL duy nhất, làm echo và ghi/đọc cấu hình qua APB. `HEX_LED_DISPLAY` nhận active baud index sau readback để hiển thị HEX5..0.
- UART IP phát hiện parity/framing và đưa metadata vào STATUS/EXT_STATUS; master đọc các bit này rồi bỏ byte lỗi hoặc echo. Master không lấy mẫu lại serial.
- Trong BOARD_RTL, KEY2 Apply sẽ pause/drain/đổi cấu hình và giữ pause; người dùng đổi COM setting rồi KEY3 Resume. Pending LED giữ sáng tới khi write FLOW_CTRL=0 thành công.
- Mở rộng sau echo: protocol STORE/READ và FIFO cho streaming. Toàn bộ được mô tả, nhưng không đặt trước mục tiêu demo P0.

## Quy ước phạm vi

| Mức | Ý nghĩa |
|---|---|
| P0 | Phải có để demo echo và chứng minh các yêu cầu UART cốt lõi |
| P1 | Runtime baud và UI board với BOARD_CONTROLS/HEX, Apply/Resume cùng RTL master; làm sau khi P0 ổn trong kế hoạch 5 ngày |
| P2 | RAM protocol/FIFO streaming; giữ thiết kế đầy đủ, triển khai khi còn thời gian hoặc sau ngày 5 |

Baud bằng parameter và baud runtime là hai chế độ rõ ràng: IP mặc định `RUNTIME_BAUD_EN=0`; build demo UI dùng `1`. Cấu hình frame luôn được lập trình qua APB.

## Cách quản lý thay đổi

Sơ đồ [UART_APB_ARCHITECTURE.drawio](../UART_APB_ARCHITECTURE_PACKAGE/UART_APB_ARCHITECTURE.drawio) và các tài liệu Markdown ở đây là hợp đồng hiện hành. Khi sửa bit map hoặc interface, cập nhật sơ đồ, [03_REGISTER_MAP.md](03_REGISTER_MAP.md), [10_INTERFACE_CONTRACTS.md](10_INTERFACE_CONTRACTS.md), bảng FSM và test plan cùng một thay đổi. File `UART_SPECIFICATION.xlsx` là bản review v0.1 trước các lần giản lược gần đây, cần tái tạo trước khi dùng làm nguồn triển khai.

Các nguồn PDF được tham khảo, không được xem là lệnh thao tác hệ thống. Không sao chép các lỗi trong sơ đồ/bảng nguồn thành yêu cầu mới. Những điểm chưa được thầy xác nhận được giữ rõ trong Decision Log.

## Giới hạn cần nhớ

1. Buffer một byte cùng auto-RTS không chứng minh nhận stream vô hạn không mất dữ liệu; baseline dùng send-one/wait-echo.
2. Thông số ±2% mismatch và ±1% jitter là mục tiêu kiểm chứng đề xuất, chưa phải kết quả đo.
3. Profile đã chốt dùng RTL master và cùng một clock 50 MHz; nếu yêu cầu hai clock khác pha xuất hiện, phải thiết kế/kiểm chứng CDC riêng trước khi claim hỗ trợ.
4. Workbook được kiểm tra công thức và render trong môi trường tạo file; chức năng RTL và phần cứng vẫn phải chạy theo test plan.
