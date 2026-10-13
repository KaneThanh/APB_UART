# APB UART — RTL implementation

Mã nguồn **Verilog-2001** cho bản kiến trúc đã thống nhất ngày 11/10/2026: UART APB, master echo hoàn toàn RTL, BOARD_CONTROLS và HEX. Toàn bộ hardware dùng `.v` và header `.vh`; chỉ testbench dùng SystemVerilog `.sv`. Không dùng CPU, firmware hoặc IP UART có sẵn.

**Specification tổng thể:** [02_SYSTEM_SPEC.md](../uart_design_20261011/02_SYSTEM_SPEC.md), đối chiếu RTL hiện hành ngày 12/10/2026.

**Bắt đầu đọc:** [các điểm cần xem lại](NOTES_FOR_REVIEW.md), [kết quả kiểm chứng](VERIFICATION_RESULTS.md), rồi [top UART](rtl/uart_apb_top.v) và [top DE2-115](board/de2_115_uart_top.v).

## Cấu trúc mã nguồn

| File | Chức năng |
|---|---|
| `rtl/uart_functions.vh` | Hàm Verilog cục bộ trong module: bảng 9 baud, baud ↔ index, tính độ rộng counter |
| `rtl/reset_sync.v` | Assert reset bất đồng bộ, release qua 2 FF; startup thêm 3 cạnh |
| `rtl/uart_sync.v` | RX/CTS synchronizer, phát hiện cạnh xuống RX |
| `rtl/uart_apb_slave.v` | Handshake APB zero-wait; `wr_fire`, `rd_fire` tại completion |
| `rtl/uart_regs.v` | ADDRESS_ACCESS_DECODE, TX_CFG_BAUD_FLOW_REGS, READ_DATA_MUX |
| `rtl/uart_tx.v` | Ba module TX_FSM, TX_FRAME_DATAPATH, TX_BIT_TIMER và wrapper |
| `rtl/uart_rx.v` | Ba module RX_FSM, RX_FRAME_DATAPATH, RX_TIMING và wrapper |
| `rtl/uart_rx_slot.v` | RX_BUFFER_FLOW: slot 8 bit, valid, metadata parity/framing, RTS |
| `rtl/uart_apb_top.v` | UART IP; nối các khối theo architecture |
| `rtl/apb_transaction_master.v` | Một request outstanding; IDLE → SETUP → ACCESS → DONE |
| `rtl/apb_echo_master.v` | Boot 8N1, poll/read/echo, discard lỗi RX, Apply/Resume, HOST_FAULT |
| `board/board_controls.v` | Đồng bộ/debounce KEY/SW, chọn pending baud/config, pulse Apply/Resume |
| `board/hex_display.v` | Sáu digit active-low, hiển thị baud đã xác nhận; pending/error LED |
| `board/de2_115_uart_top.v` | Top board nối control → master → APB UART; không có Nios |
| `tb/` | Năm testbench tự kiểm tra, có timeout và `$fatal` khi sai |
| `sim/rtl.f`, `sim/run.ps1`, `sim/run.do` | Thứ tự compile, regression Icarus, script ModelSim/Questa |
| `sim/synthesize.tcl` | Chạy Analysis & Synthesis Quartus, xuất report |
| `board/uart.qsf`, `board/uart.sdc` | Device/pin/I/O standard đầy đủ cho 58 cổng DE2-115; SDC cần review async và external I/O trước timing sign-off |
| `board/PIN_ASSIGNMENTS.md` | Bảng chân, mức điện áp JP6/JP7 và mapping LED sang LEDR |

TX/RX được tách FSM, datapath và timer thành module thực, dù các module cùng engine được đặt chung file để tiện đọc. Baud timer tạo **clock enable**, không tạo clock mới. Không có TX oversampling counter.

## UART IP ports và parameters

| Port | Chiều | Bits | Ý nghĩa |
|---|---|---:|---|
| `clk` | Input | 1 | Clock duy nhất cho UART và APB, mặc định 50 MHz |
| `reset_n` | Input | 1 | Reset toàn core, active-low |
| `psel`, `penable`, `pwrite` | Input | 1 mỗi port | Điều khiển APB |
| `paddr` | Input | 12 | Địa chỉ byte; aligned 4 |
| `pwdata`, `prdata` | Input / Output | 32 | Dữ liệu APB |
| `pstrb` | Input | 4 | Chỉ byte 0 chứa các field hiện có |
| `pready`, `pslverr` | Output | 1 mỗi port | Completion / lỗi APB |
| `rx`, `cts_n` | Input | 1 mỗi port | Serial RX, quyền phát active-low |
| `tx`, `rts_n` | Output | 1 mỗi port | Serial TX, khả năng nhận active-low |

`CLK_FREQ=50000000`, `BAUDRATE=115200`, `OVERSAMPLE=16`, `RUNTIME_BAUD_EN=0`. Top board bật `RUNTIME_BAUD_EN=1`. CFG core reset bằng 0 (**5N1**); master boot ghi CFG=3 (**8N1**). Không nối SW trực tiếp vào CFG hoặc timer.

## Register map được triển khai

| Offset | Register | Nội dung |
|---|---|---|
| `0x000` | TX_DATA | Staging `[7:0]`; được ghi cả khi TX busy |
| `0x004` | RX_DATA | Read-clear slot khi valid; empty read trả 0 |
| `0x008` | CFG | `[1:0]=N−5`, `[2]=2 stops`, `[3]=parity enable`, `[4]=even` |
| `0x00C` | CTRL | Bit 0 W1P START; đọc 0; busy thì reject |
| `0x010` | STATUS | `[0]=!tx_busy`, `[1]=rx_valid`, `[2]=slot parity error` |
| `0x014` | EXT_STATUS | `[0]=tx_busy`, `[1]=rx_busy`, `[2]=frame error`, `[3]=CTS`, `[4]=RTS`, `[5]=full`, `[6]=cfg_safe`, `[7]=runtime capability` |
| `0x018` | Unmapped | PSLVERR; không có ERROR/W1C bank |
| `0x01C` | BAUD_SEL | Index 0…8; runtime-disabled effective write bị reject |
| `0x020` | FLOW_CTRL | Bit 0 pause RX bằng RTS; không hủy frame đang nhận |

Baud index 0…8: **2400, 4800, 9600, 19200, 38400, 57600, 76800, 115200, 230400**.

CFG/BAUD effective write cần `sync_ready && !tx_busy && !rx_busy && !slot_valid && rx_sync`. Mọi side effect chỉ xảy ra khi APB completion không lỗi. Metadata thuộc byte đang giữ, không phải lịch sử sticky. Chi tiết chuẩn tắc: [register contract](../uart_design_20261011/03_REGISTER_MAP.md), [FSM contract](../uart_design_20261011/11_FSM_TABLES.md).

## Chạy mô phỏng

Trong PowerShell:

```powershell
cd D:\Documents\EDABK\Digital_Design\UART\RTL\sim
.\run.ps1
# Chạy riêng:
.\run.ps1 -Tests tb_board
# Hoặc chỉ định simulator đã cài:
.\run.ps1 -IcarusDir C:\iverilog\bin
```

Script kiểm tra riêng hai hardware top bằng `-g2001`, sau đó compile/chạy các testbench bằng `-g2012`. Vì vậy việc testbench dùng SystemVerilog không che lỗi ngôn ngữ trong hardware. Script dừng khi compile/simulation lỗi hoặc thiếu marker PASS; log ở `sim/logs/`. Bản Icarus đặt riêng trong `tools/` phục vụ máy hiện tại, không thay PATH toàn hệ thống. Khi chạy qua môi trường sandbox của agent, compiler cần chạy ngoài process sandbox; xem ghi chú tool trong NOTES. Trên máy khác cần cài Icarus hoặc cung cấp thư mục có đầy đủ runtime DLL.

Với ModelSim/Questa đang hoạt động, chạy từ `sim/`:

```text
vsim -c -do "set TEST tb_uart_apb; do run.do"
```

Với Quartus:

```powershell
& 'D:\DATA\Quartus_lite\quartus\bin64\quartus_sh.exe' -t .\synthesize.tcl
```

Đây là synthesis toàn top board, **chưa phải** fit/STA/program DE2-115. Không dùng project synthesis để nạp board khi chưa điền constraint.

## Thao tác demo đã mã hóa

1. Reset KEY0; chờ HEX hiển thị 115200, master đã cấu hình 8N1.
2. PC gửi một word rồi chờ echo; bật RTS/CTS, tắt local echo và XON/XOFF.
3. Muốn đổi cấu hình: dừng PC gửi, chờ echo cuối. SW[1:0] chọn 5…8 data bits; SW2 parity enable; SW3 even; SW4 two stops. KEY1 chọn pending baud, KEY2 Apply.
4. Pending LED sáng; master pause/drain/chờ safe/ghi/readback. HEX chỉ đổi sau khi xác nhận baud active. Đổi COM setting PC cho khớp, rồi KEY3 Resume.
5. LED[0]=pending/chờ Resume; LED[1]=host fault APB/readback. Host fault cần reset. Byte parity/framing lỗi chỉ bị bỏ, không bật host fault.

Tên net DE2-115: `UART_RTS` là **input** nối `cts_n`; `UART_CTS` là **output** nối `rts_n`. Sáu HEX hiển thị đủ baud; HEX0 là hàng đơn vị.
