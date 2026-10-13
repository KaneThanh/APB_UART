# Testplan — UART APB và hệ thống echo DE2-115

Ngày cập nhật: **12/10/2026**. Thư mục testbench của project là `RTL/tb/`.

Tài liệu này giải thích **testbench tạo tín hiệu gì, kiểm tra gì và vì sao kết luận PASS/FAIL**. Nội dung được đối chiếu với năm file `.sv` hiện có và RTL đã bỏ `pclk`, `presetn`. UART IP hiện dùng duy nhất `clk` và `reset_n`.

**Trạng thái:** các bài ghi “Có sẵn” đã được viết trong source testbench. Đây không phải xác nhận lần chạy mới. Việc viết tài liệu này không chạy mô phỏng hoặc tổng hợp; log và report cũ không chứng minh phiên bản RTL mới nhất đã PASS.

## 1. Testbench đứng ở đâu trong hệ thống?

**DUT** là phần RTL đang được kiểm tra. Testbench chạy trong simulator, tạo clock/reset và đóng vai thiết bị bên ngoài DUT; không được tổng hợp lên FPGA.

| Bài test | DUT | Testbench đóng vai gì? |
|---|---|---|
| [tb_uart_apb.sv](tb_uart_apb.sv) | `uart_apb_top` | APB master cấu hình/đọc/ghi UART; thiết bị UART ngoài gửi vào RX và kiểm tra TX |
| [tb_parameters.sv](tb_parameters.sv) | 9 instance `uart_apb_top` | APB master và UART peer cho từng giá trị parameter BAUDRATE |
| [tb_races.sv](tb_races.sv) | `uart_apb_top` | APB master và UART peer cố tình tạo các sự kiện cùng cạnh clock |
| [tb_units.sv](tb_units.sv) | `uart_rx_slot`, `apb_transaction_master`, `board_controls` | Điều khiển trực tiếp từng khối; giả lập APB slave có wait-state; tạo KEY/SW |
| [tb_board.sv](tb_board.sv) | `de2_115_uart_top` | PC UART và người bấm nút/gạt switch; theo dõi HEX/LED và giao dịch APB |

**Khác biệt quan trọng:** trong `tb_uart_apb`, task của testbench tự lái APB. Trong `tb_board`, **APB Echo Master RTL thật** tự lái APB; testbench chỉ gửi serial và thao tác board. Vì vậy test core PASS chưa đủ để kết luận hệ thống echo PASS.

Luồng kiểm tra core:

1. Testbench ghi CFG/BAUD_SEL bằng APB.
2. Testbench ghi TX_DATA rồi CTRL.START; checker quan sát `tx`.
3. Đồng thời, UART peer của testbench phát frame vào `rx`.
4. UART RTL nhận frame và lưu byte/metadata vào RX slot.
5. Testbench đọc STATUS, EXT_STATUS và RX_DATA để kiểm tra kết quả.

Luồng kiểm tra board:

**PC giả lập → UART RX → RX slot → Echo Master đọc APB → ghi TX_DATA/START qua APB → UART TX → PC checker.**

Không mô phỏng chip USB–UART, điện áp RS-232 hoặc dây thực trong các bài này. `UART_RXD`, `UART_TXD` là tín hiệu logic phía FPGA.

## 2. Những quy ước phải hiểu trước khi đọc test

### 2.1 Clock, reset và thời gian

| Nội dung | Quy ước |
|---|---|
| Clock | `always #10 clk=~clk`: chu kỳ 20 ns, tương ứng 50 MHz |
| Timescale | `1ns/1ps`; các delay được viết theo ns |
| Reset core | `reset_n=0` để reset; nhả reset bằng `reset_n=1` |
| Reset board | KEY[0] active-low, đi qua reset synchronizer của board |
| Startup | Reset nội bộ nhả qua 2 FF; `sync_ready` lên sau thêm 3 cạnh clock |
| CTS/RTS | Active-low: 0 cho phép truyền/nhận; 1 yêu cầu chờ |
| UART idle | RX/TX ở mức 1; start bit ở mức 0 |
| Thứ tự data | LSB trước: bit 0, bit 1, …, bit N−1 |

APB driver thường đổi tín hiệu tại **cạnh xuống**, rồi DUT xử lý tại **cạnh lên**. Cách này tránh driver và DUT cùng thay đổi/chốt tín hiệu ở một thời điểm không rõ thứ tự.

Khi kiểm tra giá trị register sau cập nhật, test có thể chờ `#1` sau cạnh lên để các phép gán nonblocking hoàn tất. Riêng đọc APB phải lấy `prdata` tại cạnh completion, **trước khi side effect read-clear xóa RX slot**.

### 2.2 Frame và CFG

`CFG[4:0] = {parity_even, parity_en, two_stop, data_bits_minus_5[1:0]}`.

| Field | Giá trị |
|---|---|
| CFG[1:0] | 0/1/2/3 tương ứng 5/6/7/8 data bits |
| CFG[2] | 0: 1 stop bit; 1: 2 stop bits |
| CFG[3] | 0: không parity; 1: có parity |
| CFG[4] | Khi parity bật: 0 odd; 1 even |

| Format | CFG | Số bit cả frame |
|---|---:|---:|
| 5N1 | `0x00` | 1 start + 5 data + 1 stop = 7 |
| 8N1 | `0x03` | 10 |
| 8E1 | `0x1B` | 11 |
| 7E2 | `0x1E` | 11 |
| 6O2 | `0x0D` | 10 |
| 8E2 | `0x1F` | 12 |

**Core reset về 5N1. Board Echo Master boot ghi CFG=3 để chuyển sang 8N1.** Không nhầm reset default của UART IP với cấu hình demo sau boot.

Trong task serial, argument `par` có quy ước riêng: **0=none, 1=even, 2=odd**. Đây không phải mã trực tiếp của một field thanh ghi.

Parity được tính chỉ trên N data bits: `xor_data = data[0] ^ … ^ data[N-1]`. Even parity dùng `xor_data`; odd parity dùng `!xor_data`. Với `0xA6` ở 8 bit, data có bốn bit 1 nên even parity=0 và odd parity=1.

### 2.3 Baud và reference timing

UART peer trong testbench dùng `Tbit = 1e9 / baud` ns, **không dùng baud tick của DUT** để phát/giải mã serial. Nhờ vậy, một lỗi timer trong DUT không tự động xuất hiện giống hệt ở checker.

| BAUD_SEL | Baud | Tbit xấp xỉ, ns |
|---:|---:|---:|
| 0 | 2400 | 416666.667 |
| 1 | 4800 | 208333.333 |
| 2 | 9600 | 104166.667 |
| 3 | 19200 | 52083.333 |
| 4 | 38400 | 26041.667 |
| 5 | 57600 | 17361.111 |
| 6 | 76800 | 13020.833 |
| 7 | 115200 | 8680.556 |
| 8 | 230400 | 4340.278 |

TX checker đợi cạnh xuống start, kiểm tra giữa start ở `0.5*Tbit`, sau đó lấy mẫu mỗi `Tbit` tại tâm data/parity/stop. RX peer giữ mỗi bit đủ `Tbit`; đầu frame được lệch một khoảng nhỏ so với clock để không luôn trùng cạnh clock.

RX RTL dùng sampling ×16: giữa start ở raw tick thứ 8; sau đó lấy mẫu data/parity/stop mỗi 16 raw tick. Testbench phát serial theo thời gian thực mô phỏng, còn RX tự tạo các sample enable bên trong.

## 3. Register và kết quả cần quan sát

| Offset | Register | Điều cần kiểm tra |
|---:|---|---|
| `0x000` | TX_DATA | Giữ byte staging; write không tự phát frame |
| `0x004` | RX_DATA | Trả byte slot, zero-extend 32 bit; successful read khi valid sẽ pop; empty read trả 0 |
| `0x008` | CFG | Giữ frame config; effective write chỉ được chấp nhận khi cfg_safe |
| `0x00C` | CTRL | Bit 0 START là W1P; đọc trả 0; START khi busy bị reject |
| `0x010` | STATUS | [0]=TX idle, [1]=RX valid, [2]=slot parity error |
| `0x014` | EXT_STATUS | [0]=TX busy, [1]=RX busy, [2]=slot framing error, [3]=CTS level đã sync, [4]=RTS level, [5]=slot full, [6]=cfg_safe, [7]=runtime baud capability |
| `0x018` | Unmapped | Báo PSLVERR; không có ERROR/W1C bank |
| `0x01C` | BAUD_SEL | Baud index 0…8; không phải giá trị baud nguyên |
| `0x020` | FLOW_CTRL | Bit 0 pause RX; pause tác động lên RTS, không hủy frame đang nhận |

`cfg_safe = sync_ready && !tx_busy && !rx_busy && !slot_valid && rx_sync`.

Effective write là write tác động field thấp, cần `pstrb[0]=1`. Với register ghi hợp lệ, `pstrb=0` hoặc chỉ các byte cao có thể là no-op. Tuy nhiên, **write vào register read-only vẫn bị reject dù pstrb=0**; không dùng quy tắc no-op để bỏ qua lỗi quyền truy cập.

Metadata parity/framing thuộc **byte đang nằm trong slot**. Đọc RX_DATA pop byte sẽ clear metadata nếu không có frame mới thay thế cùng cạnh. Không có sticky error history hoặc sticky overrun register.

## 4. Một giao dịch APB được test như thế nào?

Task `bus(wr, addr, data, strb, expect_error, result)` trong `tb_uart_apb` thực hiện:

| Bước | Driver làm gì? | Checker mong đợi gì? |
|---:|---|---|
| 1 — SETUP | Tại negedge: PSEL=1, PENABLE=0; đặt PWRITE/PADDR/PWDATA/PSTRB | Ở posedge tiếp theo, PREADY=0 theo implementation hiện tại |
| 2 — ACCESS | Tại negedge tiếp theo: PENABLE=1; giữ payload | Ở posedge completion, PREADY=1 vì UART slave zero-wait |
| 3 — Response | Chốt PRDATA tại completion | PSLVERR đúng `expect_error`; transfer lỗi không có write/pop/START side effect |
| 4 — Kết thúc | Tại negedge: bỏ PSEL/PENABLE và strobe | Không lặp side effect của cùng transfer |

Điều kiện completion: `psel && penable && pready`. `rd_fire`/`wr_fire` chỉ được phép tác động khi transfer thành công.

**Ví dụ negative test:** ghi START lần nữa khi TX busy. Checker yêu cầu `PSLVERR=1`. Nếu DUT trả lỗi đúng như mong đợi thì testcase **PASS**. PSLVERR của DUT không đồng nghĩa testbench FAIL; FAIL là phản hồi không đúng kỳ vọng.

UART slave hiện zero-wait. Bài giữ ACCESS nhiều chu kỳ nằm trong `tb_units`, với một **slave giả lập** để kiểm tra APB transaction master có giữ payload khi PREADY=0 hay không.

## 5. Testplan chi tiết theo từng file

Các ID dưới đây là mã truy vết trong tài liệu; source hiện dùng thông báo `check()` và chưa in các ID này vào log.

### 5.1 tb_uart_apb — UART IP và register interface

| ID | Có sẵn: stimulus / thao tác | Kết quả bắt buộc |
|---|---|---|
| C01 | Reset, chờ startup, đọc CFG/BAUD/STATUS/RX_DATA | TX=1, RTS=1 và PREADY=0 trong reset; sau startup CFG=0, baud index=7, STATUS=1, empty RX_DATA=0 |
| C02 | Đọc/ghi 0x018; đọc 0x001; ghi RX_DATA/STATUS/EXT_STATUS | PSLVERR=1; unmapped read trả 0; không cập nhật dữ liệu của write bị reject |
| C03 | Ghi baud index=9; đọc lại BAUD_SEL | Reject, baud index vẫn là 7 |
| C04 | Ghi BAUD_SEL với strobe byte cao; ghi CFG với strobe=0 | Giao dịch hợp lệ nhưng không đổi field; CFG vẫn 0 |
| C05 | FLOW_CTRL=1 rồi FLOW_CTRL=0 khi slot empty | RTS lên 1 khi pause, xuống 0 sau resume |
| C06 | Chạy đủ 9 baud × 4 data lengths × 3 parity modes × 2 stop counts, TX và RX đồng thời | Đủ **216 case full-duplex**; mỗi case TX/RX đúng payload, frame và baud |
| C07 | Tắt parity nhưng đặt parity_even=1 | TX vẫn không thêm parity bit |
| C08 | CTS=1; ghi TX_DATA=0xC3 và START; đợi 100 clock | TX giữ idle=1, TX busy=1 do đang chờ CTS |
| C09 | Khi TX đang chờ CTS: ghi START/CFG/BAUD có tác động; đồng thời thử các no-op | Effective START/CFG/BAUD bị reject; no-op hợp lệ không gây side effect |
| C10 | Khi frame 0xC3 đã pending: ghi staging=0x3C; sau đó CTS xuống 0 | Frame phát vẫn là 0xC3 đã snapshot; staging mới không sửa frame pending |
| C11 | CTS lên 1 sau khi TX đã bắt đầu | Frame hiện tại vẫn hoàn tất, không bị cắt giữa chừng |
| C12 | Gửi parity sai cho 0xA5; giữ slot full; gửi thêm frame khác | Giữ byte đầu 0xA5 và parity flag của nó; frame mới bị drop, không thay metadata cũ |
| C13 | Gửi stop sai, gồm lỗi ở stop cuối của frame hai stop | RX valid=1, đúng data, framing flag=1; metadata bao gồm sample stop cuối |
| C14 | Phát low pulse 500 ns ở 230400 baud rồi đưa RX lên 1 | False start bị loại, không tạo RX valid |
| C15 | Giữ RX low dài; đọc byte break, tiếp tục giữ low | Chỉ commit một frame lỗi cho một khoảng low liên tục; không lặp byte khi chưa trở lại high |
| C16 | Gửi peer với bit period ×0.98 và ×1.02, 5…8 data bits, even parity, 2 stop tại 230400 | Nhận đúng data, không parity/framing error trong các case đã chọn |
| C17 | Trong khi RX nhận frame: thử ghi CFG/BAUD | Reject, frame đang nhận vẫn được đọc đúng |
| C18 | Reset khi TX đang pending do CTS=1 | Hủy frame pending; TX/RTS về idle/reset, STATUS trở về 1 sau startup |

Trong C06, task được chạy bằng `fork/join`:

1. Ghi CFG và BAUD_SEL; ghi TX staging=0xA6.
2. Một nhánh chạy `expect_tx(0xA6, ...)`.
3. Một nhánh chạy `send_word(0x59, ...)` vào RX.
4. Một nhánh ghi CTRL.START qua APB.
5. Chờ cả ba nhánh xong; `expect_rx()` kiểm tra và pop RX slot.

Với N data bits, RX expected là `0x59 & ((1<<N)-1)`; các bit ngoài N phải bằng 0. 216 case tương ứng 216 frame TX và 216 frame RX; không phải 216 giá trị payload khác nhau.

**TX checker còn kiểm tra thời gian:** TX busy phải giữ qua phần cuối stop cuối. Thời gian từ start tới hết busy không được ngắn hơn frame lý tưởng, trong dung sai so sánh 0.1 ns; không được dài hơn frame lý tưởng quá 20.1 ns. Giới hạn này đang được kiểm tra trong matrix, tại clock 50 MHz.

**RX checker thực hiện:** đọc STATUS/EXT_STATUS → so valid/parity/framing → kiểm tra RTS high khi full → đọc RX_DATA → so data → đọc lại status → kiểm tra clear metadata và RTS low sau pop.

### 5.2 tb_parameters — baud được chọn khi build RTL

`tb_parameters` tạo **9 DUT chạy song song**, mỗi DUT có một BAUDRATE parameter khác nhau và `RUNTIME_BAUD_EN=0`. Đây là mô phỏng 9 cấu hình build; không đổi parameter của cùng một DUT lúc đang chạy.

| ID | Có sẵn: thao tác trên mỗi DUT | Kết quả bắt buộc |
|---|---|---|
| P01 | Đọc BAUD_SEL sau reset | Index đúng parameter RATE của DUT đó |
| P02 | Đọc EXT_STATUS[7] | Runtime capability=0 |
| P03 | Ghi BAUD_SEL với pstrb[0]=1 | PSLVERR=1 dù idle; baud không đổi |
| P04 | Ghi BAUD_SEL với chỉ strobe byte cao | No-op hợp lệ, index vẫn giữ nguyên |
| P05 | Cấu hình 8N1; TX 0x96 và RX 0x69 đồng thời | Serial timing phù hợp RATE; STATUS=3 khi TX idle và RX valid; RX_DATA=0x69 |
| P06 | Chờ finished của cả 9 instance | Chỉ kết thúc tổng khi tất cả 9 DUT xong |

Giới hạn: bài này dùng 8N1, không lặp lại đủ 24 format. Hàm `baud_value()` trong header RTL được dùng để tạo RATE cho các instance; do đó riêng bảng RATE của bài này chưa hoàn toàn độc lập. Matrix C06 dùng bảng baud riêng trong testbench và bổ sung đối chiếu serial độc lập.

### 5.3 tb_races — hai sự kiện xảy ra cùng cạnh clock

Những bài này chủ động nhìn vào tín hiệu nội bộ để căn đúng cạnh. Đây là kiểm tra ưu tiên cập nhật storage/control; không dùng tín hiệu nội bộ làm reference cho baud.

| ID | Có sẵn: điều kiện và thao tác | Kết quả bắt buộc |
|---|---|---|
| R01 | Slot có 0x11; frame mới 0x22 có stop lỗi; đọc RX_DATA đúng cạnh rx_push | APB trả **byte cũ 0x11**; sau cạnh đó slot giữ **0x22 + framing error** |
| R02 | Slot empty; đọc RX_DATA đúng cạnh frame 0x33 commit | APB trả 0 của trạng thái trước cạnh; frame 0x33 mới vẫn nằm trong slot, không bị pop mất |
| R03 | CFG write hoàn tất cùng lúc rx_fall báo start | Reject write; CFG vẫn 8N1 |
| R04 | START mới hoàn tất đúng cạnh TX kết thúc frame cũ | Reject do busy trước cạnh; không tự khởi động thêm frame |
| R05 | Reset trong lúc TX và RX đang hoạt động | Assert reset lập tức đưa TX/RTS/PREADY về trạng thái reset; sau nhả reset STATUS=1, không còn frame/slot cũ |

**Quy tắc đọc R01:** master thấy dữ liệu trước cạnh; register cập nhật trạng thái sau cạnh. Không kiểm tra RX_DATA sau pop rồi mong còn thấy byte cũ.

### 5.4 tb_units — kiểm tra riêng buffer, master bus và Board Controls

| ID | DUT | Có sẵn: stimulus | Kết quả bắt buộc |
|---|---|---|---|
| U01 | RX slot | Empty → push 0xA5, parity bad | Slot valid, data=0xA5, parity flag=1, RTS=1 |
| U02 | RX slot | Khi full, push 0x5A không pop | Giữ 0xA5 và metadata cũ |
| U03 | RX slot | Pop và push 0x5A cùng cạnh, framing bad | Thay slot bằng 0x5A; parity clear, framing set, valid vẫn 1 |
| U04 | RX slot | Pop không push | Clear valid/data/metadata; RTS=0 nếu không pause |
| U05 | RX slot | Đặt rx_pause_next=1 | RTS cập nhật high cùng cạnh xử lý pause |
| U06 | APB transaction master | Handshake request ghi 0x024/0xDEADBEEF/strobe=5; sau đó đổi request payload | APB dùng payload đã latch, không bị payload đầu vào mới làm thay đổi |
| U07 | APB transaction master | PREADY=0 thêm 7 ACCESS cycles | PSEL/PENABLE và toàn bộ payload giữ ổn định, done=0 |
| U08 | APB transaction master | Completion với PRDATA=0xABCD1234, PSLVERR=1 | Capture response đúng; bỏ PSEL; done chỉ một chu kỳ; trở về req_ready |
| U09 | APB transaction master | Request đọc với req_strb đầu vào khác 0 | PSTRB trên APB vẫn 0; đọc thành công trả response_data=77 |
| U10 | Board Controls | KEY1 low ngắn rồi high | Bounce ngắn không tăng baud index |
| U11 | Board Controls | Giữ KEY1 low lâu, sau đó nhả và bấm lại | Mỗi lần nhấn chỉ tăng một lần; index 8 wrap về 0 |
| U12 | Board Controls | SW=10101, đợi đồng bộ/ổn định | pending_cfg=0x0D, tương ứng 6O2 |
| U13 | Board Controls | Bấm KEY1/KEY2/KEY3 đồng thời | Apply ưu tiên; một apply_req, không resume_req, không tăng index vì thao tác cùng lúc |
| U14 | Board Controls | Nhả rồi bấm KEY3 | Một resume_req cho lần nhấn |

`DEBOUNCE_CYCLES=4` trong mô phỏng để test chạy nhanh. Đây không phải giá trị debounce dùng cho nút cơ khí thực trên board. RX slot trong bài unit được cấp `sync_ready=1` trực tiếp; không dùng bài này để kết luận startup timing đã được kiểm tra đủ.

### 5.5 tb_board — hệ thống RTL đầy đủ trên board

| ID | Có sẵn: thao tác | Kết quả bắt buộc |
|---|---|---|
| B01 | Reset bằng KEY0, chờ master boot | HEX blank trong reset; active baud index=7; UART CFG=3 (8N1); pending/error LED clear |
| B02 | Kiểm tra HEX sau boot | Sáu digit hiển thị 115200, active-low segment đúng theo code |
| B03 | Gửi 16 byte `i*17`: 00,11,…,FF ở 115200/8N1; chờ echo từng byte | Echo đúng; **đúng một APB START write** cho mỗi byte tốt |
| B04 | Cho CTS phía FPGA high, gửi 0x81 | Echo Master đã START nhưng TX chờ CTS, không xuất start sớm |
| B05 | KEY1 chọn baud index=8, SW chọn 7E2, bấm Apply khi frame cũ pending | Pending setting chưa thành active; Apply đợi frame cũ kết thúc |
| B06 | Sau Apply đổi SW trở lại 8N1 trước khi apply hoàn tất | Master vẫn dùng snapshot 7E2 của lần Apply; không lấy SW mới |
| B07 | Cho CTS low để frame cũ phát xong, đợi active baud=8 | Cấu hình 230400/7E2 được ghi/readback; pending LED=1 và RTS high, chờ Resume |
| B08 | Bấm Resume, gửi 0x65 ở 230400/7E2 | Pending clear, RTS low; echo đúng theo cấu hình mới |
| B09 | Gửi parity sai hoặc stop cuối sai | Master pop/discard byte lỗi; không thêm START; không bật host fault LED |
| B10 | Apply trong trạng thái paused; chọn index 8→0 và 8N1; Apply lại | Reapply giữ pause, active baud thành 2400; sau Resume echo 0x5A đúng |
| B11 | Force PSLVERR để giả lập lỗi bus | Master vào HOST_FAULT, bật error LED, ngừng PSEL/PENABLE; reset khôi phục boot |
| B12 | Force PRDATA sai ở boot readback, dù bus không báo lỗi | HOST_FAULT; active baud vẫn invalid=15, không công bố cấu hình chưa xác nhận; reset khôi phục |

Tên chân board dễ nhầm:

- `UART_RTS` là **input board**, được nối vào `cts_n` của UART IP. Test đặt `UART_RTS=1` để chặn FPGA TX.
- `UART_CTS` là **output board**, từ `rts_n` của UART IP. Task gửi của PC đợi `UART_CTS=0` mới bắt đầu frame.
- Khi nối USB–UART qua GPIO, vẫn đọc theo **chiều tín hiệu**, không suy từ tên RTS/CTS in trên connector.

Counter `starts` đếm START APB thành công; `apb_pops` đếm successful RX_DATA reads, gồm cả empty read nếu có. Vì vậy `apb_pops` không phải số byte nhận hợp lệ tuyệt đối.

## 6. Ví dụ để tự theo dõi một byte 0xA6

Chọn 115200, 8N1, CTS=0, UART đã startup:

1. APB ghi `CFG=0x03` tại 0x008 và `BAUD_SEL=7` tại 0x01C.
2. APB ghi `TX_DATA=0xA6` tại 0x000. TX vẫn idle vì chưa START.
3. APB ghi `CTRL=1` tại 0x00C. `tx_accept` được tiêu thụ tại completion; frame được snapshot.
4. TX bắt đầu sau điều kiện CTS/startup. Trên chân TX: **start=0 → data 0,1,1,0,0,1,0,1 → stop=1**.
5. Checker lấy mẫu giữa từng bit. 8N1 có 10 bit, thời gian frame lý tưởng khoảng **86.806 µs**.
6. Nếu gửi cùng byte vào RX, RX lắp data vào `rx_word`; tại sample stop cuối, `rx_push` commit slot.
7. STATUS.RX_VALID=1, RX_DATA=0x000000A6, parity/framing flags=0; RTS high vì slot full.
8. Successful RX_DATA read lấy byte rồi phát `rx_pop`; slot empty và RTS low nếu không pause.

Trong core test, APB task thực hiện bước đọc/ghi này. Trong board test, Echo Master RTL thực hiện bước lấy RX_DATA rồi phát lại qua TX.

## 7. Cách chạy và hiểu log

### 7.1 Chạy bằng Icarus

Mở PowerShell, chuyển tới thư mục simulator:

```powershell
Set-Location 'D:\Documents\EDABK\Digital_Design\UART\RTL\sim'
```

Nên học và chạy theo thứ tự: **unit → core → parameters → races → board**.

```powershell
.\run.ps1 -Tests tb_units
.\run.ps1 -Tests tb_uart_apb
.\run.ps1 -Tests tb_parameters
.\run.ps1 -Tests tb_races
.\run.ps1 -Tests tb_board
```

Chạy toàn bộ với thứ tự mặc định của script:

```powershell
.\run.ps1
```

Nếu simulator ở đường dẫn khác:

```powershell
.\run.ps1 -IcarusDir 'C:\iverilog\bin' -Tests tb_uart_apb
```

[run.ps1](../sim/run.ps1) ưu tiên Icarus nằm trong `RTL/tools/iverilog/ucrt64/bin`; nếu không có thì tìm trên PATH. Trên máy khác cần cài Icarus cùng runtime cần thiết.

Mỗi lần chạy script có hai bước:

1. Compile riêng hai hardware top bằng **Verilog-2001**, `-g2001`.
2. Compile và mô phỏng các testbench được chọn bằng **SystemVerilog**, `-g2012`.

Ngay cả khi chỉ chọn `tb_units`, script vẫn compile hai hardware top ở bước 1. Hardware `.v` và testbench `.sv` dùng ngôn ngữ khác nhau có chủ đích.

| File kết quả | Cách đọc |
|---|---|
| `sim/logs/<test>.compile.log` | Lỗi cú pháp, tên port không khớp, thiếu module/header hoặc cảnh báo compile |
| `sim/logs/<test>.run.log` | Thông báo check, thời gian lỗi và marker PASS cuối |
| `sim/logs/results.json` | Tổng kết lần script chạy thành công; xem thời điểm file để tránh đọc nhầm kết quả cũ |

Marker kết thúc mong đợi:

```text
PASS tb_units: ...
PASS tb_uart_apb: 216 duplex format cases, ...
PASS tb_parameters: 9 parameter builds TX/RX
PASS tb_races: ...
PASS tb_board: ...
```

Các dòng `PASS baud=...` trong core hoặc `PASS BAUDRATE parameter=...` chỉ là tiến độ từng nhóm. **Phải có marker tổng của testbench** mới coi bài đó hoàn tất. `checks` là số lần gọi check, không phải số format hoặc coverage phần trăm.

### 7.2 Chạy ModelSim/Questa

Từ `RTL/sim`, khi simulator đã được cài và có trên PATH:

```text
vsim -c -do "set TEST tb_uart_apb; do run.do"
```

Đổi `tb_uart_apb` thành tên bài muốn chạy. [run.do](../sim/run.do) compile hardware theo Verilog-2001, testbench theo SystemVerilog rồi `run -all`.

### 7.3 Xem waveform để học testbench

Testbench hiện chưa tự ghi VCD. Không tìm waveform file chỉ từ việc chạy Icarus với script hiện tại. Có thể mở ModelSim/Questa và nhập vào Transcript, với working directory là `RTL/sim`:

```tcl
vlib work
vlog -vlog01compat -work work -f rtl.f
vlog -sv -work work +incdir+../rtl ../tb/tb_uart_apb.sv
vsim work.tb_uart_apb
add wave -r sim:/tb_uart_apb/*
run -all
```

Nếu thư viện `work` đã có thì bỏ bước `vlib work`. `add wave -r` thêm hierarchy để quan sát; sau đó gom/ẩn các tín hiệu ít quan trọng trong cửa sổ Wave.

| Luồng cần xem | Tín hiệu nên thêm |
|---|---|
| Reset/startup | `clk`, `reset_n`, `dut.rst_n_int`, `dut.sync_ready` |
| APB transfer | `psel`, `penable`, `pwrite`, `paddr`, `pwdata`, `pstrb`, `prdata`, `pready`, `pslverr`, `dut.wr_fire`, `dut.rd_fire` |
| TX | `tx`, `cts_n`, `dut.cts_n_sync`, `dut.tx_accept`, `dut.tx_busy`, `dut.u_tx.tx_load`, `dut.u_tx.tx_begin`, `dut.u_tx.tx_bit_tick`, `dut.u_tx.tx_finish` |
| RX | `rx`, `dut.rx_sync`, `dut.rx_fall`, `dut.rx_busy`, `dut.u_rx.rx_half_tick`, `dut.u_rx.rx_bit_tick`, `dut.u_rx.rx_data_sample`, `dut.rx_word`, `dut.rx_push` |
| Slot/flow | `dut.slot_data`, `dut.slot_valid`, `dut.slot_parity_bad`, `dut.slot_frame_bad`, `dut.rx_pop`, `rts_n` |
| Board, khi chạy tb_board | `KEY`, `SW`, `LED`, `dut.pending_cfg`, `dut.pending_baud_index`, `dut.active_baud_index`, `dut.u_master.state`, `dut.psel`, `dut.paddr` |

Các tên ở bảng là hierarchical paths trong testbench tương ứng. Khi đổi tên instance trong RTL, cập nhật đường dẫn waveform và các white-box check trong testbench.

## 8. PASS/FAIL và timeout

Một testcase PASS khi kết quả đúng kỳ vọng của bảng, kể cả testcase cố tình yêu cầu DUT báo lỗi. Một testbench PASS khi mọi check hoàn tất và có marker tổng. Regression PASS khi tất cả bài được chọn compile/chạy thành công, không `$fatal` và không thiếu marker PASS.

| Testbench | Watchdog theo thời gian mô phỏng |
|---|---:|
| tb_units | 100 µs |
| tb_uart_apb | 500 ms |
| tb_parameters | 10 ms |
| tb_races | 2 ms |
| tb_board | 30 ms |

Đây là **thời gian mô phỏng**, không phải số giây đợi trên PC. Bài 2400 baud có frame dài hơn các bài baud cao. Không sửa watchdog để che một điều kiện `wait()` bị kẹt.

| Triệu chứng | Cách tìm nguyên nhân |
|---|---|
| Compile báo port không tồn tại | Kiểm tra tên port/instance; interface hiện không còn pclk/presetn |
| Timeout khi chờ TX | Kiểm tra đã ghi START chưa, CTS đã low và sync_ready đã high chưa, APB write có bị reject không |
| Timeout khi PC gửi trong tb_board | Kiểm tra UART_CTS/RTS còn high do pause/full; đã bấm Resume chưa |
| Data sai | Kiểm tra baud/CFG hai phía, LSB-first và mask theo data length |
| Parity flag sai | Kiểm tra quy ước par=1 even/par=2 odd và chỉ XOR N data bits |
| RX_DATA=0 dù đã gửi | Kiểm tra false start, slot bị pop trước lúc đọc, frame chưa tới sample stop cuối hoặc config không khớp |
| Metadata của byte khác | Xem cạnh rx_push/rx_pop và trạng thái slot trước cạnh; dùng R01/R02 để kiểm tra ưu tiên |
| Error LED sáng | Phân biệt HOST_FAULT APB/readback với parity/framing của byte; byte lỗi serial được discard và không tự bật host fault |
| Chỉ thấy PASS của một baud | Chờ marker tổng; bài khác có thể còn chạy hoặc sau đó FAIL |

## 9. Phần chưa được kiểm chứng đầy đủ

Không coi matrix 216 case là coverage toàn bộ hệ thống. Các mục dưới đây là **kế hoạch bổ sung**, chưa phải những gì năm testbench hiện đã chứng minh.

| ID | Bài cần bổ sung | Cách làm cụ thể | Điều kiện hoàn tất |
|---|---|---|---|
| G01 | Payload rộng hơn | Duyệt mọi giá trị 0…2^N−1 cho từng N; thêm pattern 00/FF/55/AA và chuỗi random có seed | TX/RX đúng từng payload, kết quả tái lập được từ seed |
| G02 | Tolerance và phase sweep | Quét offset start theo nhiều vị trí trong chu kỳ clock; quét sai lệch bit period cho nhiều baud/format; jitter phải có biên được chốt | Báo rõ phạm vi pass/fail; không suy từ vài case ±2% ra mọi cấu hình |
| G03 | Burst với handshake có độ trễ | Peer đã bắt đầu frame trước RTS high, hoặc gửi thêm frame sau tín hiệu stop; thử lúc slot full | Xác nhận full/drop giữ byte cũ; báo số frame bị bỏ. Một slot không đảm bảo lossless cho mọi burst |
| G04 | Reset/startup theo từng cạnh | Đổi pha reset assertion/release; reset tại start/data/parity/stop/APB ACCESS | Không ghost frame/START/pop; rst_n_int/sync_ready đúng chuỗi release |
| G05 | APB liên tiếp và tất cả strobe | APB back-to-back với PSEL giữ high, PENABLE có SETUP đúng; quét pstrb và invalid addresses | Mỗi completion chỉ một side effect; legal no-op/permission error đúng contract |
| G06 | Lỗi ở từng pha Apply/Resume | Inject PSLVERR hoặc readback mismatch vào các bước CFG/BAUD/FLOW_CTRL, không chỉ boot/poll | Host dừng đúng, không công bố active setting sai, reset khôi phục |
| G07 | HEX đầy đủ và invalid index | Test trực tiếp hex_display cho cả 9 baud và index ngoài 0…8 | Mọi digit/segment và blank invalid đúng |
| G08 | Assertions/coverage tự động | Bổ sung checker APB payload stable, side effect đúng completion, done một chu kỳ; thu coverage theo case | Có report các bin đã hit/missing; không dùng số checks thay coverage |
| G09 | Clock/parameter ngoài profile | Nếu muốn hỗ trợ clock khác 50 MHz, chọn thêm CLK_FREQ rồi kiểm tra baud timing; chốt cách xử lý parameter không hợp lệ | Có kết quả cho từng cấu hình được công bố hỗ trợ |

Chứng minh metastability, timing closure và khả năng chịu nhiễu dây cần kiểm tra phần cứng/STA/CDC thích hợp; waveform logic trong simulator không đo được các yếu tố đó. Demo PC thật cần adapter có đúng điện áp, frame/baud support và CTS/RTS khi kiểm tra flow control.

## 10. Checklist và biên bản lần chạy

Trước khi chạy:

- [ ] Xác nhận đang dùng đúng source RTL và năm file testbench hiện hành.
- [ ] UART top chỉ dùng clk/reset_n; mọi instance khớp interface.
- [ ] Simulator và include path tìm được `uart_functions.vh`.
- [ ] Chốt bài muốn chạy; phân biệt expected PSLVERR với test FAIL.

Sau khi chạy:

- [ ] Compile hardware Verilog-2001 thành công.
- [ ] Từng bài được chọn có marker tổng PASS, không timeout/$fatal.
- [ ] Core đủ 216 full-duplex case; parameter test đủ 9 instance nếu các bài này được chọn.
- [ ] Lưu source revision hoặc bản source đi kèm log và thời điểm chạy.
- [ ] Ghi rõ bài chưa chạy, gap chưa bổ sung và giới hạn coverage.

| Trường | Điền sau lần chạy thực tế |
|---|---|
| Ngày/giờ, người chạy | … |
| Source revision / bản source | … |
| Simulator và version | … |
| Các bài đã chọn | … |
| Kết quả từng bài | … |
| Đường dẫn log | … |
| Lỗi đầu tiên và thời điểm mô phỏng, nếu có | … |
| Gap chưa kiểm tra | … |

Tài liệu liên quan: [register map](../../uart_design_20261011/03_REGISTER_MAP.md), [interface](../../uart_design_20261011/10_INTERFACE_CONTRACTS.md), [FSM tables](../../uart_design_20261011/11_FSM_TABLES.md), [flowchart master](../../uart_design_20261011/12_APB_MASTER_FLOWCHART.md). Bài kiểm chứng hệ thống cần đọc cùng RTL và testbench hiện tại; report cũ chỉ là bằng chứng của source tại thời điểm report đó được tạo.
