# Trạng thái và thuật toán

## Avalon→APB

| State | Input/condition | Output/side effect | Next |
|---|---|---|---|
| IDLE | read hoặc write | Latch address, writedata, byteenable, direction; waitrequest=1 | SETUP |
| IDLE | Không request | PSEL=0, PENABLE=0 | IDLE |
| SETUP | Luôn | PSEL=1, PENABLE=0 | ACCESS |
| ACCESS | PREADY=0 | Giữ mọi APB signal; waitrequest=1 | ACCESS |
| ACCESS | PREADY=1 | Chốt PRDATA, pulse error nếu PSLVERR | DONE |
| DONE | Luôn | waitrequest=0, readdata đã chốt; PSEL=0 | IDLE |
| Bất kỳ | reset_n=0 | Hủy request chưa hoàn tất, xóa trạng thái | IDLE |

Avalon master phải giữ request/address/data khi waitrequest=1. Transfer được Avalon chấp nhận tại cạnh clock trong DONE. APB side effect chỉ có một lần trước đó, tại ACCESS/PREADY. Cầu không pipeline nhiều request và không dùng readdatavalid. Byte address12bit, byteenable4bit đưa nguyên sang PSTRB.

## Firmware

Mỗi `app_step` chỉ làm một lượng việc hữu hạn; không đợi UART hoàn tất frame hoặc LCD phát xong ký tự.

| Trạng thái | Hoạt động | Chuyển tiếp |
|---|---|---|
| Boot | Pause RX, bỏ RX cũ nếu có, chờ cfg_safe | Ghi/verify8N1/B7, chạy |
| Run | Poll RX, pop metadata+word, enqueue echo, service TX, IO và LCD | Apply→Drain |
| Drain | Giữ pause, tiếp tục nhận slot đã đến và xả queue/TX | queue=0 và cfg_safe→ghi/verify CFG+BAUD→Paused |
| Drain timeout | Đã2s mà chưa safe | Ghi cờ lỗi, hủy Apply, trở về Run với cấu hình cũ |
| Paused | Config mới đã ghi, tiếp tục UI/LCD | Resume hoặc resume_queued→Run |

Priority trong vòng: controls → RX → TX → queue backpressure → config FSM → FLOW update → diagnostics → LCD refresh nếu đến kỳ. SW6 snapshot được lấy trong controls. Do vậy snapshot có thể phản ánh RX valid trước khi CPU pop trong cùng vòng.

Parity/frame bad lấy từ STATUS/EXT **trước** RX_DATA read-pop. CPU là reader duy nhất của RX_DATA. LCD chỉ đọc các status không side effect; không tự ý pop dữ liệu.

Hàng đợi dùng head/tail modulo512, count0..512. RX chỉ pop khi count<512. Báo cáo16byte chỉ enqueue nếu còn đủ16chỗ. TX dequeue sau hai writes TX_DATA/START khi TX ready. UART hiện tại bảo đảm nhận START khi không busy; lỗi bus được bộ đếm độc lập phản ánh.

## LCD

| State | Thao tác | Thời gian |
|---|---|---|
| Power-up | EN=0, chờ nguồn ổn định | ≥50ms |
| Prepare | Chọn data/command, RS, giữ EN=0 | ≥1us setup |
| Enable | EN=1 | ≥1us |
| Hold/wait | EN=0, giữ data/RS | ≥5ms |
| Advance | Tăng bước init hoặc cursor | Quay Prepare |

Init: 0x30,0x30,0x30,0x38,0x08,0x01,0x06,0x0C. Refresh cursor0 command0x80;1..16 là text[0..15];17 command0xC0;18..33 là text[16..31]. Framebuffer được CPU ghi độc lập với state machine. Không cần CPU delay từng LCD instruction.
