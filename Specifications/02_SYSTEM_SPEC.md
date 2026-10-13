# Specification hệ thống UART APB — DE2-115

> Bổ sung 12/10/2026: tài liệu này mô tả **profile RTL Master**. Profile thay master bằng Nios II và bổ sung LCD có đặc tả, firmware và phần cứng riêng tại [NIOS_LCD/README.md](../NIOS_LCD/README.md). Hai profile dùng chung UART APB, không nối đồng thời hai master. Profile Nios chưa có SOF CPU do thiếu CPU IP trong bộ cài hiện tại.

**Phiên bản 0.2.0 · 12/10/2026 · Hardware Verilog-2001 · Host hoàn toàn RTL.**

Đây là đặc tả tổng thể hiện hành, thay cho v0.1 trong file này. Nội dung hợp nhất yêu cầu đã chốt, kiến trúc và hành vi RTL; các giới hạn/chưa triển khai được ghi rõ. Việc viết specification không chạy mô phỏng hoặc tổng hợp. Report cũ không xác nhận phiên bản mới nhất đã PASS sau khi xóa pclk/presetn.

Yêu cầu đã thống nhất với người dùng là cơ sở; RTL và testbench phải đáp ứng hợp đồng dưới đây. Khác biệt cần được ghi nhận và xử lý, không tự coi mọi hành vi của code là yêu cầu của đề bài. Runtime baud, Board UI và Echo Master là các lựa chọn của project.

## 1. Phạm vi và yêu cầu

Hệ thống nhận word UART từ PC, đọc qua APB bằng Echo Master RTL và phát lại qua UART. Người dùng thay cấu hình bằng KEY/SW; host ghi/đọc thanh ghi UART qua APB. Không dùng CPU Nios hoặc firmware.

Word dài 5–8 bit nhưng storage rộng 8 bit. TX bỏ qua bit ngoài N; RX zero-extend bit cao. Echo đi qua APB và storage của host, không nối tắt RX sang TX.

| ID | Yêu cầu/hợp đồng |
|---|---|
| REQ-01 | Hỗ trợ 2400, 4800, 9600, 19200, 38400, 57600, 76800, 115200, 230400 baud |
| REQ-02 | Chọn baud khi build bằng parameter BAUDRATE |
| REQ-03 | APB cấu hình 5/6/7/8 data bits |
| REQ-04 | Không parity hoặc một parity bit odd/even |
| REQ-05 | Một hoặc hai stop bits |
| REQ-06 | Cấu hình và điều khiển hoạt động qua APB |
| REQ-07 | Automatic RTS/CTS: RTS theo khả năng nhận, CTS chặn bắt đầu TX |
| REQ-08 | Full-duplex; TX tick ×1, RX lấy mẫu ×16 |
| REQ-09 | Một RX holding slot, metadata parity/framing theo word |
| REQ-10 | Echo Master RTL đọc bỏ byte lỗi serial, echo byte tốt |
| REQ-11 | Board Controls tạo request; Apply ghi/readback, Resume mở lại RX |
| REQ-12 | Runtime BAUD_SEL khi RUNTIME_BAUD_EN=1 |
| REQ-13 | Sáu HEX hiển thị toàn bộ baud active; LED pending/error |
| REQ-14 | Một miền clock 50 MHz; reset assert async/release sync; chỉ clk/reset_n ở UART top |
| REQ-15 | APB transfer lỗi không tạo write/pop/START side effect |
| REQ-16 | Full + push không pop phải giữ word cũ, bỏ word mới |

REQ-01…07 là chức năng theo yêu cầu UART; các mục còn lại là hợp đồng triển khai/board đã chọn. Ngoài baseline: RAM lưu chuỗi, PC command parser, FIFO nhiều phần tử, interrupt/DMA, sticky error/W1C, auto-baud, majority voting, hai clock độc lập và streaming lossless cho mọi adapter.

## 2. Kiến trúc và ownership

![Board system](../UART_APB_ARCHITECTURE_PACKAGE/previews/page_01.png)

`de2_115_uart_top` là top-level để chạy trên board. `uart_apb_top` là UART IP nằm bên trong và có thể dùng độc lập với APB master khác cùng clock.

| Khối RTL | Trách nhiệm / storage thuộc khối |
|---|---|
| de2_115_uart_top | Nối clock/reset, UI, master, UART, display và chân board |
| board_controls | Synchronize/debounce KEY/SW, pending config/baud và request pulses |
| apb_echo_master | Boot, poll/echo, Apply/Resume, fault; giữ một temp_byte và config request snapshot |
| apb_transaction_master | Chốt request bus, SETUP/ACCESS/DONE và response |
| hex_display | Decode active baud; register HEX/LED |
| uart_apb_top | Kết nối APB slave/registers, TX/RX, sync, slot và reset |
| uart_apb_slave | Handshake tổ hợp, rd_fire/wr_fire, PREADY/PSLVERR |
| uart_regs | Decode/guard, TX staging, CFG/baud/pause storage, read mux/status |
| uart_tx | Wrapper TX FSM + frame datapath + bit timer |
| uart_tx_frame_datapath | Frame_shift[11:0], bits_left[3:0], registered tx |
| uart_tx_bit_timer | Baud snapshot và fractional accumulator TX |
| uart_rx | Wrapper RX FSM + frame datapath + timing |
| uart_rx_frame_datapath | CFG snapshot, data/stop index, rx_word, parity/error state |
| uart_rx_timing | Baud snapshot, accumulator ×16 và OS counter[3:0] |
| uart_sync | Hai chuỗi 2 FF RX/CTS riêng và history phát hiện RX falling edge |
| uart_rx_slot | Word/valid/parity/framing của slot và registered RTS |
| reset_sync | Reset release chain và startup ready |

![UART Simple Datapath](../UART_APB_ARCHITECTURE_PACKAGE/previews/page_05.png)

Mỗi register có một owner. TX staging khác frame đang phát; RX word đang lắp khác word trong holding slot. ADDRESS_ACCESS_DECODE, TX_CFG_BAUD_FLOW_REGS và READ_DATA_MUX trên draw.io là ba phần logic trong uart_regs, không phải module độc lập. CLOCK / RESET INPUTS và SHARED CONTROL NETS (WIRES) là ký hiệu nguồn/dây; RESET_SYNC là module thực.

## 3. Parameters và clock/reset

| Parameter | Default | Miền/hợp đồng |
|---|---:|---|
| CLK_FREQ | 50000000 | Hz, khớp clock thật; baseline 50 MHz |
| BAUDRATE | 115200 | Một trong chín giá trị REQ-01 |
| OVERSAMPLE | 16 | Chỉ hỗ trợ 16 |
| RUNTIME_BAUD_EN | 0 | 0 cố định baud theo build; 1 cho APB đổi baud |
| DEBOUNCE_CYCLES | CLK_FREQ/100 | Board Controls; ≥1; default khoảng 10 ms |

Board top bật RUNTIME_BAUD_EN=1. Baud boot theo BAUDRATE parameter; host boot không ghi đè baud bằng một hằng 115200.

**Giới hạn parameter:** OVERSAMPLE còn khai báo ở top nhưng RX timing hiện thực cố định ×16; đổi parameter này không đổi thuật toán. RTL hiện không có elaboration assertions. BAUDRATE sai làm helper baud_index trả 15 và baud_value ngoài miền fallback 115200; đây không phải cấu hình được hỗ trợ. Board host fault khi đọc index >8. Clock khác 50 MHz cần kiểm chứng lại, tối thiểu CLK_FREQ >16×baud_max cho thuật toán timer này.

- Toàn hệ thống cập nhật cạnh lên clk; trên board clk=CLOCK_50. UART top chỉ có clk/reset_n, không có pclk/presetn riêng.
- reset_n active-low. reset_sync assert rst_n_int bất đồng bộ; nhả qua hai FF, thêm ba cạnh clock tạo sync_ready.
- PREADY=0 khi rst_n_int=0. Sau nhả reset nội bộ, APB có thể hoạt động trước sync_ready; CFG/BAUD write bị guard chặn. START có thể tạo frame pending nhưng TX chỉ bắt đầu khi startup ready.
- RX/CTS qua hai FF riêng, reset về 1; rx_prev reset=1; rx_fall=rx_prev && !rx_sync.
- Board có reset_sync từ KEY0; UART IP có reset_sync riêng. Vì vậy startup board/core có thêm latency; host poll CFG_SAFE. Output board_ready hiện không có consumer.
- Reset hủy request/frame/slot đang chờ; TX=1, RTS=1, storage/counters/metadata=0, RX pause=0, CFG=0 (5N1), BAUD_SEL=baud_index(BAUDRATE).
- Sau startup với line high, slot empty và không pause, RTS xuống 0. Core reset 5N1; board host boot ghi CFG=3 để chuyển 8N1.

## 4. Interface ngoài

### 4.1 UART IP — uart_apb_top

| Cổng | Chiều | Bit | Ý nghĩa |
|---|---|---:|---|
| clk | Input | 1 | Clock chung APB/core |
| reset_n | Input | 1 | Reset ngoài active-low |
| psel | Input | 1 | Chọn slave |
| penable | Input | 1 | ACCESS phase |
| pwrite | Input | 1 | 1 ghi, 0 đọc |
| paddr | Input | 12 | Byte offset, aligned 4, decode toàn bộ 12 bit |
| pwdata | Input | 32 | Write data |
| pstrb | Input | 4 | Byte enables |
| prdata | Output | 32 | Read data trước side effect tại completion |
| pready | Output | 1 | Hoàn tất ACCESS |
| pslverr | Output | 1 | Lỗi transfer tại completion |
| rx | Input async | 1 | Serial RX, idle high |
| cts_n | Input async | 1 | Low cho phép bắt đầu TX |
| tx | Output | 1 | Serial TX đã đăng ký, idle/reset high |
| rts_n | Output | 1 | Low thông báo sẵn sàng nhận, output đã đăng ký |

### 4.2 Board top — de2_115_uart_top

| Cổng | Chiều | Bit | Ý nghĩa |
|---|---|---:|---|
| CLOCK_50 | Input | 1 | Clock 50 MHz |
| KEY | Input | 4 | Active-low: reset, chọn baud, Apply, Resume |
| SW | Input | 5 | Lựa chọn frame pending |
| UART_RXD | Input | 1 | Nối UART IP rx |
| UART_RTS | Input | 1 | Nối UART IP cts_n; tên board khác tên phía IP |
| UART_TXD | Output | 1 | Nối UART IP tx |
| UART_CTS | Output | 1 | Nối UART IP rts_n |
| HEX0…HEX5 | Output | 7 mỗi digit | Active-low, [6:0]=g,f,e,d,c,b,a |
| LED | Output | 2 | [0]=pending; [1]=host error; 1 bật |

### 4.3 UI/host/display

| Tín hiệu | Bit | Producer → Consumer | Hợp đồng |
|---|---:|---|---|
| pending_cfg | 5 | UI → host | Frame dự kiến, chụp khi Apply |
| pending_baud_index | 4 | UI → host | Index dự kiến 0…8 |
| apply_req / resume_req | 1 mỗi tín hiệu | UI → host | Pulse một clock |
| active_baud_index | 4 | host → display | Index đã xác nhận; reset=15 nghĩa là chưa hợp lệ |
| pending | 1 | host → display | Apply đã nhận, chưa Resume xong |
| error | 1 | host → display | HOST_FAULT, giữ tới reset |

active_cfg nằm nội bộ host, không có output hiển thị. HEX chỉ hiển thị baud active.

## 5. Hợp đồng APB

Profile có PSTRB, PREADY và PSLVERR; không có PPROT. Các tín hiệu APB đồng bộ với clk. Không quảng bá các chức năng APB không có trong interface.

| Pha | Điều kiện | Hành vi |
|---|---|---|
| IDLE | PSEL=0 | Không side effect |
| SETUP | PSEL=1, PENABLE=0 | Master đặt/giữ payload; slave PREADY=0 |
| ACCESS | PSEL=1, PENABLE=1 | UART zero-wait nếu rst_n_int=1 |
| Completion | Cạnh lên khi PSEL && PENABLE && PREADY | Chốt response và thực hiện side effect hợp lệ |

```text
pready  = rst_n_int && psel && penable
pslverr = pready && access_error
wr_fire = pready && pwrite  && !access_error
rd_fire = pready && !pwrite && !access_error
```

rd_fire/wr_fire là enable tổ hợp tiêu thụ ở cạnh lên, không phải clock. Master phải kết thúc ACCESS hoặc sang SETUP sau completion; giữ ACCESS sau PREADY=1 qua nhiều cạnh có thể lặp side effect và không phải một transfer hợp lệ duy nhất.

PRDATA là read mux tổ hợp. Chỉ sử dụng ở read completion; RX_DATA trả word trước cạnh rồi mới pop. UART không stall để chờ TX idle/RX valid: busy START trả lỗi, empty RX read trả 0. Host phải poll status.

Address ngoài map/không aligned hoặc write read-only đều lỗi. Transfer lỗi không có write/pop/START. Với register ghi hợp lệ, pstrb[0]=0 là no-op cho field hiện tại; write read-only vẫn lỗi dù strobe=0. Reserved bits read=0, write ignored. Không alias địa chỉ bằng cách bỏ qua bit cao paddr.

## 6. Register map đầy đủ

| Offset | Register | Access | Reset storage / side effect |
|---:|---|---|---|
| 0x000 | TX_DATA | RW | Reset 0; write staging, không tự START |
| 0x004 | RX_DATA | RO/read-pop | Empty trả 0; read thành công khi valid thì pop |
| 0x008 | CFG | RW guarded | Reset 0 = 5N1 |
| 0x00C | CTRL | W1P, read=0 | START không phải stored bit |
| 0x010 | STATUS | RO | Status động, không clear khi đọc |
| 0x014 | EXT_STATUS | RO | Status động, không clear khi đọc |
| 0x018 | Unmapped | Lỗi | PSLVERR; không ERROR/W1C bank |
| 0x01C | BAUD_SEL | RW guarded/capability | Reset baud_index(BAUDRATE) |
| 0x020 | FLOW_CTRL | RW | Reset 0, điều khiển RX pause |

### 6.1 TX_DATA, RX_DATA, CTRL

TX_DATA[7:0] được ghi khi pstrb[0]=1; read zero-extend. Có thể ghi khi TX busy nhưng không sửa frame đã snapshot. RX_DATA[7:0] là word trong slot, zero-extend; bit ngoài N bằng 0. Empty read trả 0.

CTRL[0]=START: write 1 với strobe thấp tạo tx_accept khi !tx_busy; write 0 no-op. CTRL read luôn 0. CTS high không gây PSLVERR cho START: frame được chấp nhận vào WAIT_CTS. Bits còn lại của các register này read=0/write ignored; RX_DATA là read-only.

### 6.2 CFG

| Field | Bits | Encoding |
|---|---|---|
| DATA_BITS | [1:0] | 0→5, 1→6, 2→7, 3→8 |
| TWO_STOP | [2] | 0→1 stop; 1→2 stop |
| PARITY_EN | [3] | 0 không parity; 1 có parity |
| PARITY_EVEN | [4] | 1 even; 0 odd; ignored nếu parity disabled |
| Reserved | [31:5] | Read=0, write ignored |

```text
cfg_safe = sync_ready && !tx_busy && !rx_busy && !slot_valid && rx_sync
```

Effective CFG write cần cfg_safe; nếu không, PSLVERR và giữ CFG cũ. Guard đánh giá trạng thái trước cạnh completion. Guard không yêu cầu pause=1; việc Pause là quy trình do host tổ chức.

Ví dụ: 5N1=0x00; 8N1=0x03; 8E1=0x1B; 7E2=0x1E; 8E2=0x1F; 6O2=0x0D.

### 6.3 STATUS và EXT_STATUS

| Register | Bit | Tên | Ý nghĩa mức 1 |
|---|---:|---|---|
| STATUS | 0 | TX_DONE/TX_IDLE | !tx_busy; có thể nhận START mới |
| STATUS | 1 | RX_DONE/RX_VALID | Slot có word |
| STATUS | 2 | PARITY_ERR | Word trong slot có parity mismatch |
| STATUS | 31:3 | Reserved | 0 |
| EXT_STATUS | 0 | TX_BUSY | WAIT_CTS hoặc SEND |
| EXT_STATUS | 1 | RX_BUSY | START_CHECK/DATA/PARITY/STOP |
| EXT_STATUS | 2 | FRAME_ERR | Word trong slot có stop sample thấp |
| EXT_STATUS | 3 | CTS_LEVEL | cts_n_sync high, đang chặn TX mới |
| EXT_STATUS | 4 | RTS_LEVEL | rts_n high, yêu cầu peer ngừng gửi |
| EXT_STATUS | 5 | RX_FULL | Slot valid |
| EXT_STATUS | 6 | CFG_SAFE | Đạt điều kiện đổi CFG/BAUD |
| EXT_STATUS | 7 | RUNTIME_BAUD | Capability cố định của build |
| EXT_STATUS | 31:8 | Reserved | 0 |

TX_DONE là mức idle, không phải sticky completion. Parity/framing độc lập, có thể cùng 1; gắn với word trong slot, clear khi pop nếu không có word thay thế. Không có sticky history cho frame bị drop.

### 6.4 BAUD_SEL và FLOW_CTRL

| Index | Baud | HEX5…HEX0 |
|---:|---:|---|
| 0 | 2400 | 002400 |
| 1 | 4800 | 004800 |
| 2 | 9600 | 009600 |
| 3 | 19200 | 019200 |
| 4 | 38400 | 038400 |
| 5 | 57600 | 057600 |
| 6 | 76800 | 076800 |
| 7 | 115200 | 115200 |
| 8 | 230400 | 230400 |

BAUD_SEL[3:0]=index, [31:4] reserved. Effective write cần cfg_safe, RUNTIME_BAUD_EN=1 và pwdata[3:0]≤8. Nếu không thì lỗi và giữ index cũ. High-byte-only strobe là no-op hợp lệ, kể cả runtime disabled.

FLOW_CTRL[0]=RX_PAUSE; bits còn lại reserved. Write 1 làm RTS high; write 0 cho RTS low nếu ready và slot empty. Pause không hủy RX frame, không xóa slot và không gate RX FSM. RTS dùng rx_pause_next để phản ánh write tại cùng cạnh completion.

### 6.5 Trình tự cho APB host

- TX: poll STATUS[0] → write TX_DATA → write CTRL.START; poll lại STATUS[0] nếu cần biết frame đã hết. CTS high có thể khiến busy vô hạn.
- RX: poll STATUS[1], chụp parity flag → read EXT_STATUS framing flag → read RX_DATA để lấy/pop. Một master và full/drop policy giữ word/metadata ổn định tới pop.
- Reconfigure: dừng peer → FLOW_CTRL=1 → xử lý/discard byte tồn, chờ CFG_SAFE → write CFG/BAUD → readback → đổi COM settings PC → FLOW_CTRL=0. Hai write CFG/BAUD không atomic và không có rollback.

## 7. Frame và baud timing

Idle=1, một start bit=0, N data bits LSB-first, 0/1 parity bit, S stop bits=1. N=5…8, S=1…2. Có 24 format: 4 data lengths × 3 parity modes × 2 stop counts; chín baud tạo 216 cấu hình.

```text
frame_length = 1 + N + parity_en + S        (7…12 bit)
Tbit = 1 / baud
Tframe = frame_length / baud
```

Even parity bằng XOR của N data bits, odd parity là giá trị đảo. Parity không thuộc byte APB; UART tự ghép/kiểm tra. Với 0xA6 ở 8 bit, even parity=0.

Hai timer độc lập, không tạo clock mới:

| Timer | Thuật toán mỗi clk khi chạy |
|---|---|
| TX | sum=phase+baud_snapshot; nếu sum≥CLK_FREQ thì tick và phase=sum−CLK_FREQ; nếu chưa thì phase=sum |
| RX | sum=phase+16×baud_snapshot; tương tự tạo raw_tick; OS counter tạo sample events |

Fractional remainder được giữ giữa các tick trong frame. Khoảng tick có thể xen kẽ hai số chu kỳ clock nguyên gần nhất khi không chia hết. Baud snapshot rộng 18 bit; clk 50 MHz có chu kỳ 20 ns. Real arithmetic chỉ dùng trong reference testbench.

115200/8N1 có frame khoảng 86.806 µs. Throughput data lý tưởng=N/frame_length×baud bit/s. Echo còn chịu APB, CTS và cách gửi của PC; không cam kết throughput streaming tối thiểu.

## 8. TX FSM, datapath và timer

| State | Điều kiện | Action/output | Next |
|---|---|---|---|
| IDLE | Chưa accept | busy=0 | IDLE |
| IDLE | tx_accept | tx_load=1 | WAIT_CTS |
| WAIT_CTS | Chưa ready hoặc CTS high | busy=1, TX idle | WAIT_CTS |
| WAIT_CTS | sync_ready && !cts_n_sync | tx_begin=1, busy=1 | SEND |
| SEND | Chưa tick | tx_run=1, busy=1 | SEND |
| SEND | Tick, chưa last bit | tx_advance=1 | SEND |
| SEND | Tick, last bit | tx_finish=1 | IDLE |

1. tx_load pack start/data/parity/stop vào frame_shift[11:0], nạp bits_left[3:0], chụp baud. TX vẫn 1 trong lúc chờ CTS.
2. tx_begin xuất frame_shift[0]=start, clear timer phase.
3. Mỗi tick khi còn bit tiếp: xuất frame_shift[1], shift phải, giảm bits_left.
4. bits_left==1 nghĩa là đang giữ stop cuối; chỉ finish sau hết thời gian stop đó.
5. tx_finish đưa TX=1, bits_left=0; FSM về idle.

TX_BIT_TIMER đo thời gian bit; bits_left đếm số bit frame. TX không có OS counter. CTS chỉ xét trước start; đổi CTS giữa frame không cắt frame. Không CTS timeout. Ghi staging khi busy không sửa frame đã snapshot.

## 9. RX FSM, sampling và metadata

| State | Điều kiện/event | Action | Next |
|---|---|---|---|
| IDLE | sync_ready && rx_fall | rx_load | START_CHECK |
| START_CHECK | Chưa half tick | rx_run=1 | START_CHECK |
| START_CHECK | Half tick và RX low | rx_os_clr | DATA |
| START_CHECK | Half tick và RX high | Bỏ false start | IDLE |
| DATA | Bit tick | rx_data_sample; tăng index nếu chưa cuối | DATA, hoặc PARITY/STOP khi last data |
| PARITY | Bit tick | rx_parity_sample | STOP |
| STOP | Bit tick, chưa stop cuối | rx_stop_sample, tăng stop index | STOP |
| STOP | Bit tick, stop cuối | rx_stop_sample + rx_push | IDLE nếu RX high; WAIT_HIGH nếu low |
| WAIT_HIGH | RX low | Không commit thêm | WAIT_HIGH |
| WAIT_HIGH | RX high | Sẵn sàng đợi cạnh start mới | IDLE |

rx_busy=1 trong START_CHECK/DATA/PARITY/STOP. WAIT_HIGH có busy=0 nhưng CFG_SAFE vẫn false khi rx_sync low.

- rx_load snapshot CFG/baud; clear rx_word, index, parity_xor và error state.
- Start được kiểm tra ở raw tick thứ 8. rx_os_clr chỉ clear OS count; không xóa fractional phase. Sau đó đếm 16 tick tới tâm D0.
- Data/parity/stop được sample mỗi 16 raw tick: **một sample ở tâm từng bit**, không ở giữa toàn byte, không majority vote.
- rx_word[data_index] nhận rx_sync; bit cao ngoài N giữ 0. Parity XOR chỉ gồm N data bits.
- Khi parity enabled, so rx_sync với XOR hoặc đảo XOR theo CFG snapshot. Disabled thì không vào PARITY, parity_bad giữ 0.
- frame_bad OR lỗi của mọi stop sample thấp. Stop đầu sai nhưng stop cuối đúng vẫn có framing error.
- Slot dùng rx_parity_bad_next/rx_frame_bad_next để metadata gồm cả kết quả sample hiện tại. Stop cuối lỗi và rx_push cùng cạnh phải lưu lỗi ngay, không đợi thêm một clock.

RX commit tại **tâm stop cuối**. TX busy chỉ hạ sau **hết stop cuối**. RX không kiểm tra phần stop còn lại sau tâm sample. Nếu line low qua stop cuối, commit một frame lỗi rồi WAIT_HIGH để tránh lặp break frames. Không có BREAK status riêng.

## 10. RX slot và RTS/CTS

| Trạng thái trước cạnh | Push | Pop | Sau cạnh |
|---|---:|---:|---|
| Empty | 0 | 0 | Empty |
| Empty | 1 | 0 | Lưu word/metadata mới, valid=1 |
| Full | 0 | 0 | Giữ cũ |
| Full | 1 | 0 | Drop mới, giữ word và metadata cũ |
| Full | 0 | 1 | Clear valid/data/metadata |
| Full | 1 | 1 | APB trả word cũ; slot thay word/metadata mới, valid=1 |

rx_pop chỉ phát khi successful read RX_DATA và slot_valid trước cạnh=1. Empty read trùng push trả 0 cho APB và vẫn lưu word mới.

```text
store_word      = rx_push && (!slot_valid || rx_pop)
slot_valid_next = store_word || (slot_valid && !rx_pop)
rts_n_next      = !sync_ready || rx_pause_next || slot_valid_next
```

RTS output được đăng ký. RTS low khi startup xong, không pause, slot empty; high khi reset/startup/pause/full. Push/pop/write pause cập nhật RTS theo next state tại cùng cạnh.

RTS thông báo tới peer, không khóa chân RX. Frame đã bắt đầu hoặc dữ liệu gửi thêm trong độ trễ phản ứng vẫn có thể tới. Một slot không bảo đảm lossless với burst; baseline PC send-one/wait-echo. CTS đồng bộ chỉ chặn start TX, không chặn APB nhận START.

## 11. APB Transaction Master

Engine bus bên trong Echo Master; không tự chọn register hoặc quyết định echo.

| Tín hiệu | Bit | Chiều tại engine | Ý nghĩa |
|---|---:|---|---|
| req_valid | 1 | Input | Request hợp lệ, giữ payload đến handshake |
| req_ready | 1 | Output | Ready trong IDLE khi reset đã nhả |
| req_write | 1 | Input | Read/write |
| req_addr | 12 | Input | Byte offset |
| req_wdata | 32 | Input | Write payload |
| req_strb | 4 | Input | Write strobe |
| done | 1 | Output | Response valid một chu kỳ DONE |
| response_data | 32 | Output | PRDATA đã capture |
| response_error | 1 | Output | PSLVERR đã capture |

| State | Hành vi | Chuyển |
|---|---|---|
| IDLE | req_ready=1; chốt payload nếu req_valid | SETUP |
| SETUP | PSEL=1, PENABLE=0 | ACCESS sau một clock |
| ACCESS | PSEL=1, PENABLE=1, giữ payload | Đợi PREADY; capture response rồi DONE |
| DONE | done=1, PSEL/PENABLE=0 | IDLE sau một clock |

Một outstanding request. Read ép PSTRB=0. Response registers chỉ được consumer sử dụng khi done. Hỗ trợ wait-state dù UART slave zero-wait; không bus timeout. Reset hủy request đang chờ.

## 12. Echo Master

Host polling, không interrupt; issued ngăn phát lặp request trong cùng state. temp_byte[7:0]/temp_valid giữ tối đa một word tốt chờ echo.

### 12.1 Boot/echo

| State | APB/action | Khi thành công |
|---|---|---|
| WAIT_READY | Chờ req_ready | BOOT_WAIT_SAFE |
| BOOT_WAIT_SAFE | Read EXT_STATUS | Slot full thì BOOT_DRAIN_RX; CFG_SAFE thì BOOT_CFG; chưa thì poll tiếp |
| BOOT_DRAIN_RX (21) | Read/pop RX_DATA, bỏ dữ liệu nhận trước boot | BOOT_WAIT_SAFE |
| BOOT_CFG | Write CFG=3 | BOOT_VERIFY |
| BOOT_VERIFY | Read CFG | Đúng 3 thì BOOT_BAUD; sai thì fault |
| BOOT_BAUD | Read BAUD_SEL | 0…8: publish active baud, POLL_RX; ngoài miền: fault |
| POLL_RX | Read STATUS | RX_VALID: chụp parity_bad, READ_META; chưa có: poll |
| READ_META | Read EXT_STATUS | Chụp frame_bad, READ_RX |
| READ_RX | Read/pop RX_DATA | Lỗi serial: discard về poll; tốt: giữ temp_byte, WAIT_TX |
| WAIT_TX | Read STATUS | TX_IDLE thì WRITE_TX; chưa thì poll |
| WRITE_TX | Write TX_DATA=temp_byte | START_TX |
| START_TX | Write CTRL.START=1 | Clear temp_valid, POLL_RX |

Host có thể poll RX khi TX đang phát; nếu đã đọc word tiếp theo thì giữ temp_byte và đợi TX idle. Không có RAM lịch sử hoặc queue nhiều word.

### 12.2 Apply/Resume

| Bước/state | Hành vi |
|---|---|
| Nhận Apply | Snapshot pending_cfg/index; set apply_queued và pending |
| Chờ ranh giới ứng dụng | Hoàn thành word đang giữ và request outstanding; ở POLL_RX không issued/temp_valid thì PAUSE_REQ |
| PAUSE_REQ | Write FLOW_CTRL=1 |
| DRAIN_STATUS | Read EXT_STATUS: full→DRAIN_RX; CFG_SAFE→APPLY_CFG; chưa safe→poll |
| DRAIN_RX | Read/pop và discard word tồn; về DRAIN_STATUS |
| APPLY_CFG | Write CFG từ snapshot |
| APPLY_BAUD | Write BAUD_SEL từ snapshot |
| VERIFY_CFG | Readback CFG, so toàn giá trị zero-extend; mismatch→fault |
| VERIFY_BAUD | Readback baud, so snapshot và miền 0…8; mismatch→fault |
| PAUSED_READY | Publish active settings; giữ pause=1 và pending=1 |
| RESUME_REQ | Write FLOW_CTRL=0; hoàn tất thì pending=0, POLL_RX |

TX cũ đang WAIT_CTS có thể làm Apply chờ vô hạn. Drain có thể bỏ byte tồn có chủ đích. CFG/BAUD write là hai transfer riêng; không atomic, không rollback nếu bước sau lỗi.

Apply được nhận khi chưa pending hoặc đang PAUSED_READY. Apply đang chạy bỏ Apply tiếp theo. Reapply ở PAUSED_READY hợp lệ, vẫn giữ pause. Resume trong khi pending được chốt vào resume_queued và thực hiện sau khi Apply/readback hoàn tất; không bỏ pulse sớm. Resume khi không pending không được giữ cho lần Apply tương lai. Reapply mới xóa Resume của lần Apply trước. Board Controls vẫn ưu tiên Apply nếu các nút trùng chu kỳ. Snapshot không đổi theo SW sau khi nhận request.

### 12.3 HOST_FAULT

Mọi response_error, readback mismatch hoặc baud index sai đều set error=1, vào HOST_FAULT và ngừng phát request mới tới reset. Parity/framing của byte không làm host fault.

Core không tự reset/dừng do host fault. Cấu hình đã ghi trước lỗi vẫn có thể có hiệu lực; không giả định RTS high nếu lỗi xảy ra trước bước pause. pending có thể còn sáng khi lỗi trong Apply. Reset xóa fault và boot lại.

## 13. Board Controls và display

| Input | Chức năng |
|---|---|
| KEY0 | Reset, không qua debounce của ba nút chức năng |
| KEY1 | Mỗi nhấn tăng pending baud một lần, 8→0 |
| KEY2 | Apply pulse một clock sau debounce |
| KEY3 | Resume pulse một clock sau debounce |
| SW[1:0] | 00/01/10/11 → 5/6/7/8 data bits |
| SW2 | Parity enable |
| SW3 | Even=1, odd=0 |
| SW4 | Two stops=1, one stop=0 |

pending_cfg={SW3,SW2,SW4,SW1,SW0} sau đồng bộ và thời gian ổn định. Chọn xong SW, chờ ổn định rồi Apply; không cam kết snapshot đúng ý người dùng nếu gạt nhiều switch đồng thời lúc Apply.

KEY1…3 có hai FF đồng bộ và debounce counter riêng. Giữ nút không tự lặp. Nếu event đã debounce trùng clock: **Apply > Resume > tăng baud**, event ưu tiên thấp bị bỏ.

HEX0 là hàng đơn vị, HEX5 hàng trăm nghìn; zero-fill sáu chữ số. KEY1 chưa làm HEX đổi; chỉ active baud đã readback được hiển thị. Index ngoài 0…8 blank cả sáu digit. LED[0]=pending, LED[1]=error; outputs đăng ký, phản ánh input tại cạnh kế tiếp.

## 14. Kết nối PC và thao tác demo

| Đường điện | Trạng thái tích hợp |
|---|---|
| PC → RS232/USB–RS232 → DB9 → transceiver board → FPGA | QSF hiện có bốn UART pins theo đường này |
| PC → USB–UART logic 3,3 V → GPIO FPGA | Cần đổi pin mapping/board integration và I/O standard; chưa có build GPIO riêng |

Không đưa điện áp RS-232 trực tiếp vào GPIO. USB-Blaster không tự tạo cổng COM cho UART này. Với adapter logic: TXD→FPGA rx; RXD←FPGA tx; RTS active-low→FPGA cts_n; CTS active-low←FPGA rts_n; GND chung. Board cấp nguồn riêng thì không nối VCC adapter để cấp board. Chốt điện áp của bank GPIO và adapter trước khi nối.

Adapter/driver/PC application phải hỗ trợ baud và format muốn thử, đặc biệt 5/6 data bits và RTS/CTS. Bật hardware flow control; tắt local echo và XON/XOFF cho demo. Echo giữ data, không thêm CR/LF/header/checksum.

1. PC idle khi boot; đặt COM theo BAUDRATE và 8N1.
2. Reset KEY0, đợi HEX có baud hợp lệ và error LED tắt.
3. Gửi một word, chờ echo rồi mới gửi tiếp.
4. Đổi cấu hình: dừng gửi, chờ echo cuối, chọn SW/KEY1 rồi KEY2.
5. Đợi Apply hoàn tất, đổi COM settings đúng snapshot, rồi KEY3 Resume. pending tắt sau write unpause.
6. Nếu host error: kiểm tra nguyên nhân, reset để boot lại.

**Giới hạn UI:** pending sáng ngay khi nhận Apply và tiếp tục sáng ở PAUSED_READY, chưa phân biệt Applying/Ready. Khi baud đổi, HEX cập nhật là dấu hiệu readback hoàn tất. Khi chỉ đổi format, HEX không đổi; hiện chưa có đèn apply_done riêng. Resume bấm sớm trong khi pending được ghi nhớ, nhưng vẫn phải chờ Apply hoàn tất trước khi mở RX. Nên đổi cấu hình PC trước khi bấm Resume.

Slot full trước boot được Master đọc/pop rồi bỏ để tiếp tục boot. RX giữ low hoặc PC gửi liên tục không cho khoảng idle vẫn có thể trì hoãn boot. CTS high giữ TX busy hoặc RX line low kéo dài cũng có thể khiến Apply chờ; không hardware timeout. Resume không hủy frame TX đang chờ CTS và không bỏ qua CFG_SAFE.

## 15. Ưu tiên và xử lý lỗi

| Tình huống | Hợp đồng |
|---|---|
| Reset cùng mọi hoạt động | Reset ưu tiên, hủy pending request/frame/slot |
| Full read RX_DATA + push | APB trả word cũ; slot nhận word/metadata mới |
| Empty read RX_DATA + push | APB trả 0; word mới vẫn valid |
| CFG/BAUD write cùng start RX phát hiện | Guard theo trạng thái trước cạnh/rx_sync low, reject |
| START cùng TX finish | Busy trước cạnh=1, reject START mới |
| Full + push không pop | Giữ cũ, drop mới, không sticky overrun |
| Stop cuối sai + push | Commit framing error cùng word |
| Pause write + slot update | RTS dùng pause_next và occupancy_next |
| CTS đổi giữa frame | Hoàn tất frame đang phát |
| APB access lỗi | PSLVERR, không side effect, host không tự retry |
| Parity/frame error | Metadata theo slot; Echo Master đọc bỏ |
| Reset giữa Apply | Hủy snapshot/pending; boot 8N1 và baud parameter |

## 16. Kiểm chứng và nghiệm thu

[Testplan](../RTL/tb/TESTPLAN.md) chứa stimulus, expected results, waveform và lệnh chạy. ID dưới đây chỉ ra bài đã có trong source; không xác nhận bản hiện tại đã chạy PASS.

| Requirement | Testplan cases |
|---|---|
| REQ-01…05, REQ-08 | C06: 216 full-duplex cases; P01…P06: chín parameter builds; C07 parity disabled |
| REQ-06, REQ-15 | C01…C04, C09/C17; U06…U09; R03/R04 |
| REQ-07, REQ-09, REQ-16 | C05/C08/C10…C15; U01…U05; R01/R02 |
| REQ-10 | B01/B03/B04/B09/B11/B12 |
| REQ-11…13 | U10…U14; B02/B05…B10 |
| REQ-14 | C01/C18/R05/B01; hardware compile riêng Verilog-2001 |

Gate mô phỏng: năm testbench compile/chạy thành công, có marker tổng PASS, không watchdog/$fatal; matrix đủ 216 case và parameter đủ chín instance. Hardware dùng -g2001, testbench dùng SystemVerilog. ±2% hiện chỉ là bit-period tests tại 230400, 5…8 bits, even parity, hai stop; không suy thành tolerance toàn miền.

Gate implementation: exact FPGA part, đủ pin/IO standard; synthesis, fit và timing review 20 ns; review synchronizer/reset/async paths. Synthesis pass không thay timing closure hoặc demo vật lý.

Gate board đề xuất: 1000 word send-one/wait-echo 115200/8N1 đúng data/thứ tự, không fault; thêm baud thấp/cao, format adapter hỗ trợ, CTS stall và Apply/Resume. Ghi cấu hình nào chỉ được kiểm tra mô phỏng vì adapter hạn chế. Mỗi kết quả lưu source revision/bản source, tool version, ngày chạy và log.

Chưa bao phủ đầy đủ mọi payload/phase/jitter/reset state/back-to-back APB/strobe/fault injection/HEX configuration. G01…G09 trong TESTPLAN.md là các bài cần bổ sung. Metastability và nhiễu điện không được chứng minh bằng mô phỏng logic.

## 17. Giới hạn và deliverables

| Nội dung | Trạng thái / việc còn lại |
|---|---|
| RX buffer | Một slot; cần FIFO/headroom nếu yêu cầu burst lossless |
| Error history | Không sticky W1C/overrun counter; không đo số byte mất từ status |
| Timeout | Không CTS/APB/Apply timeout; watchdog testbench không phải hardware feature |
| Reconfiguration | Hai write không atomic, có drain/discard; peer phải phối hợp |
| UI | Chưa có apply_done riêng hoặc hiển thị pending config |
| Parameter | OVERSAMPLE chỉ 16; invalid parameter không bị assert chặn |
| Board constraints | QSF đã đặt EP4CE115F29C7, đủ 58 location/I/O-standard assignments theo manual; JP6=3.3 V, JP7=2.5 V mặc định. SDC vẫn cần review async/external I/O và timing sign-off; xem [pin assignments](../RTL/board/PIN_ASSIGNMENTS.md) |
| GPIO adapter | Cần pin mapping/build phù hợp; không dùng nguyên QSF DB9 để nối GPIO |
| Kết quả mới | Chưa chạy mô phỏng/tổng hợp trong lần lập specification này |
| Tài liệu lịch sử | Workbook v0.1 và revision_before_* không đại diện interface mới nhất |

Deliverables: [UART top](../RTL/rtl/uart_apb_top.v), [Board top](../RTL/board/de2_115_uart_top.v), [source list](../RTL/sim/rtl.f), [run script](../RTL/sim/run.ps1), [Board QSF](../RTL/board/uart.qsf), [testplan](../RTL/tb/TESTPLAN.md).

Sơ đồ: [draw.io](../UART_APB_ARCHITECTURE_PACKAGE/UART_APB_ARCHITECTURE.drawio.xml), [gallery](../UART_APB_ARCHITECTURE_PACKAGE/index.html). Trang 01–02 Board; 03 Host; 04–05 UART; 06–08 APB; 09–10 TX; 11–12 RX; 13 reset dùng chung. [Interface meanings](10_INTERFACE_CONTRACTS.md), [FSM tables](11_FSM_TABLES.md), [Master flowcharts](12_APB_MASTER_FLOWCHART.md).

## 18. Interface đầy đủ theo module RTL

Các bảng sau lấy tên cổng, chiều và bit width từ source hiện hành. Input/Output nhìn từ module được nêu. Parameter không phải cổng runtime. Ý nghĩa control/data/status được định nghĩa trong mục 3–15 và bảng interface liên kết ở trên.

### 18.1. `de2_115_uart_top`

Source: [de2_115_uart_top.v](../RTL/board/de2_115_uart_top.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `CLOCK_50` | Input | 1 |
| `KEY` | Input | 4 |
| `SW` | Input | 5 |
| `UART_RXD` | Input | 1 |
| `UART_RTS` | Input | 1 |
| `UART_TXD` | Output | 1 |
| `UART_CTS` | Output | 1 |
| `HEX0` | Output | 7 |
| `HEX1` | Output | 7 |
| `HEX2` | Output | 7 |
| `HEX3` | Output | 7 |
| `HEX4` | Output | 7 |
| `HEX5` | Output | 7 |
| `LED` | Output | 2 |

### 18.2. `board_controls`

Source: [board_controls.v](../RTL/board/board_controls.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `reset_n` | Input | 1 |
| `KEY` | Input | 4 |
| `SW` | Input | 5 |
| `pending_baud_index` | Output | 4 |
| `pending_cfg` | Output | 5 |
| `apply_req` | Output | 1 |
| `resume_req` | Output | 1 |

### 18.3. `apb_echo_master`

Source: [apb_echo_master.v](../RTL/rtl/apb_echo_master.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `reset_n` | Input | 1 |
| `pending_cfg` | Input | 5 |
| `pending_baud_index` | Input | 4 |
| `apply_req` | Input | 1 |
| `resume_req` | Input | 1 |
| `prdata` | Input | 32 |
| `pready` | Input | 1 |
| `pslverr` | Input | 1 |
| `psel` | Output | 1 |
| `penable` | Output | 1 |
| `pwrite` | Output | 1 |
| `paddr` | Output | 12 |
| `pwdata` | Output | 32 |
| `pstrb` | Output | 4 |
| `active_baud_index` | Output | 4 |
| `error` | Output | 1 |
| `pending` | Output | 1 |

### 18.4. `apb_transaction_master`

Source: [apb_transaction_master.v](../RTL/rtl/apb_transaction_master.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `reset_n` | Input | 1 |
| `req_valid` | Input | 1 |
| `req_write` | Input | 1 |
| `req_addr` | Input | 12 |
| `req_wdata` | Input | 32 |
| `req_strb` | Input | 4 |
| `req_ready` | Output | 1 |
| `done` | Output | 1 |
| `response_error` | Output | 1 |
| `response_data` | Output | 32 |
| `psel` | Output | 1 |
| `penable` | Output | 1 |
| `pwrite` | Output | 1 |
| `paddr` | Output | 12 |
| `pwdata` | Output | 32 |
| `pstrb` | Output | 4 |
| `prdata` | Input | 32 |
| `pready` | Input | 1 |
| `pslverr` | Input | 1 |

### 18.5. `hex_display`

Source: [hex_display.v](../RTL/board/hex_display.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `reset_n` | Input | 1 |
| `active_baud_index` | Input | 4 |
| `error` | Input | 1 |
| `pending` | Input | 1 |
| `HEX0` | Output | 7 |
| `HEX1` | Output | 7 |
| `HEX2` | Output | 7 |
| `HEX3` | Output | 7 |
| `HEX4` | Output | 7 |
| `HEX5` | Output | 7 |
| `LED` | Output | 2 |

### 18.6. `uart_apb_top`

Source: [uart_apb_top.v](../RTL/rtl/uart_apb_top.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `reset_n` | Input | 1 |
| `psel` | Input | 1 |
| `penable` | Input | 1 |
| `pwrite` | Input | 1 |
| `pstrb` | Input | 4 |
| `paddr` | Input | 12 |
| `pwdata` | Input | 32 |
| `rx` | Input | 1 |
| `cts_n` | Input | 1 |
| `prdata` | Output | 32 |
| `pready` | Output | 1 |
| `pslverr` | Output | 1 |
| `tx` | Output | 1 |
| `rts_n` | Output | 1 |

### 18.7. `uart_apb_slave`

Source: [uart_apb_slave.v](../RTL/rtl/uart_apb_slave.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `rst_n_int` | Input | 1 |
| `psel` | Input | 1 |
| `penable` | Input | 1 |
| `pwrite` | Input | 1 |
| `access_error` | Input | 1 |
| `pready` | Output | 1 |
| `pslverr` | Output | 1 |
| `wr_fire` | Output | 1 |
| `rd_fire` | Output | 1 |

### 18.8. `uart_regs`

Source: [uart_regs.v](../RTL/rtl/uart_regs.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `pwrite` | Input | 1 |
| `paddr` | Input | 12 |
| `pwdata` | Input | 32 |
| `pstrb` | Input | 4 |
| `wr_fire` | Input | 1 |
| `rd_fire` | Input | 1 |
| `tx_busy` | Input | 1 |
| `rx_busy` | Input | 1 |
| `rx_sync` | Input | 1 |
| `cts_n_sync` | Input | 1 |
| `rts_n` | Input | 1 |
| `slot_data` | Input | 8 |
| `slot_valid` | Input | 1 |
| `slot_parity_bad` | Input | 1 |
| `slot_frame_bad` | Input | 1 |
| `access_error` | Output | 1 |
| `prdata` | Output | 32 |
| `tx_data_stage` | Output | 8 |
| `cfg_active` | Output | 5 |
| `baud_active` | Output | 18 |
| `tx_accept` | Output | 1 |
| `rx_pop` | Output | 1 |
| `rx_pause_next` | Output | 1 |

### 18.9. `uart_tx`

Source: [uart_tx.v](../RTL/rtl/uart_tx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `tx_accept` | Input | 1 |
| `cts_n_sync` | Input | 1 |
| `tx_data_stage` | Input | 8 |
| `cfg_active` | Input | 5 |
| `baud_active` | Input | 18 |
| `tx` | Output | 1 |
| `tx_busy` | Output | 1 |

### 18.10. `uart_tx_fsm`

Source: [uart_tx.v](../RTL/rtl/uart_tx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `tx_accept` | Input | 1 |
| `cts_n_sync` | Input | 1 |
| `tx_bit_tick` | Input | 1 |
| `tx_last_bit` | Input | 1 |
| `tx_load` | Output | 1 |
| `tx_begin` | Output | 1 |
| `tx_run` | Output | 1 |
| `tx_advance` | Output | 1 |
| `tx_finish` | Output | 1 |
| `tx_busy` | Output | 1 |

### 18.11. `uart_tx_frame_datapath`

Source: [uart_tx.v](../RTL/rtl/uart_tx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `tx_data_stage` | Input | 8 |
| `cfg_active` | Input | 5 |
| `tx_load` | Input | 1 |
| `tx_begin` | Input | 1 |
| `tx_advance` | Input | 1 |
| `tx_finish` | Input | 1 |
| `tx` | Output | 1 |
| `tx_last_bit` | Output | 1 |

### 18.12. `uart_tx_bit_timer`

Source: [uart_tx.v](../RTL/rtl/uart_tx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `baud_active` | Input | 18 |
| `tx_load` | Input | 1 |
| `tx_begin` | Input | 1 |
| `tx_run` | Input | 1 |
| `tx_bit_tick` | Output | 1 |

### 18.13. `uart_rx`

Source: [uart_rx.v](../RTL/rtl/uart_rx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `rx_sync` | Input | 1 |
| `rx_fall` | Input | 1 |
| `cfg_active` | Input | 5 |
| `baud_active` | Input | 18 |
| `rx_word` | Output | 8 |
| `rx_push` | Output | 1 |
| `rx_busy` | Output | 1 |
| `rx_parity_bad_next` | Output | 1 |
| `rx_frame_bad_next` | Output | 1 |

### 18.14. `uart_rx_fsm`

Source: [uart_rx.v](../RTL/rtl/uart_rx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `rx_sync` | Input | 1 |
| `rx_fall` | Input | 1 |
| `rx_half_tick` | Input | 1 |
| `rx_bit_tick` | Input | 1 |
| `rx_last_data` | Input | 1 |
| `rx_last_stop` | Input | 1 |
| `rx_parity_en` | Input | 1 |
| `rx_load` | Output | 1 |
| `rx_run` | Output | 1 |
| `rx_os_clr` | Output | 1 |
| `rx_data_sample` | Output | 1 |
| `rx_parity_sample` | Output | 1 |
| `rx_stop_sample` | Output | 1 |
| `rx_push` | Output | 1 |
| `rx_busy` | Output | 1 |

### 18.15. `uart_rx_frame_datapath`

Source: [uart_rx.v](../RTL/rtl/uart_rx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `rx_sync` | Input | 1 |
| `cfg_active` | Input | 5 |
| `rx_load` | Input | 1 |
| `rx_data_sample` | Input | 1 |
| `rx_parity_sample` | Input | 1 |
| `rx_stop_sample` | Input | 1 |
| `rx_word` | Output | 8 |
| `rx_last_data` | Output | 1 |
| `rx_last_stop` | Output | 1 |
| `rx_parity_en` | Output | 1 |
| `rx_parity_bad_next` | Output | 1 |
| `rx_frame_bad_next` | Output | 1 |

### 18.16. `uart_rx_timing`

Source: [uart_rx.v](../RTL/rtl/uart_rx.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `baud_active` | Input | 18 |
| `rx_load` | Input | 1 |
| `rx_run` | Input | 1 |
| `rx_os_clr` | Input | 1 |
| `rx_half_tick` | Output | 1 |
| `rx_bit_tick` | Output | 1 |

### 18.17. `uart_sync`

Source: [uart_sync.v](../RTL/rtl/uart_sync.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `rx` | Input | 1 |
| `cts_n` | Input | 1 |
| `rx_sync` | Output | 1 |
| `cts_n_sync` | Output | 1 |
| `rx_fall` | Output | 1 |

### 18.18. `uart_rx_slot`

Source: [uart_rx_slot.v](../RTL/rtl/uart_rx_slot.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `rst_n_int` | Input | 1 |
| `sync_ready` | Input | 1 |
| `rx_pause_next` | Input | 1 |
| `rx_push` | Input | 1 |
| `rx_pop` | Input | 1 |
| `rx_word` | Input | 8 |
| `rx_parity_bad_next` | Input | 1 |
| `rx_frame_bad_next` | Input | 1 |
| `slot_data` | Output | 8 |
| `slot_valid` | Output | 1 |
| `slot_parity_bad` | Output | 1 |
| `slot_frame_bad` | Output | 1 |
| `rts_n` | Output | 1 |

### 18.19. `reset_sync`

Source: [reset_sync.v](../RTL/rtl/reset_sync.v).

| Cổng | Chiều | Số bit |
|---|---|---:|
| `clk` | Input | 1 |
| `async_reset_n` | Input | 1 |
| `rst_n_int` | Output | 1 |
| `sync_ready` | Output | 1 |

