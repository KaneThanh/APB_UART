# Kiểm chứng và công việc còn lại

Ngày 12/10/2026, trên máy hiện tại.

## Đã thực hiện

1. Biên dịch `firmware/build/uart_lcd.elf` bằng Nios II GCC12.3.1, ISA R1, không hw multiply/divide, warnings C là errors. Size: text2873, data0, bss612 bytes. Linker chừa ít nhất4KiB stack. Cảnh báo ELF RWX do code/data ở cùng RAM bare-metal, chưa có MPU.
2. Host tests chạy **chính app.c** với mock MMIO: boot1152008N1, echo tốt, bỏ parity/frame bad, giữ16ký tự, CRLF/idle gap, chọn register, một báo cáo/cạnh, xóa LCD, ngưỡng pause/resume queue, Apply/Resume sớm, timeout CTS. Không phải mô phỏng tốc độ instruction Nios.
3. RTL mới compile với `iverilog -g2001`.
4. Bridge test: SETUP/ACCESS, giữ tín hiệu qua wait states, read/write/strobe, chuyển PSLVERR, không lặp side effect, reset giữa transfer.
5. Peripheral test: dùng UART RTL thật, CFG readback, đếm lỗi unmapped APB, LCD index đầu/cuối, IO sync, TX bắt đầu/kết thúc.
6. LCD test: chuỗi power-up, pulse EN, command 0x80/0xC0, dữ liệu hai hàng. Không thay thế thử trên module vật lý.
7. Platform Designer24.1 nhận custom IP và generate `peripheral_check` thành13 files, không lỗi. Đây chỉ là peripheral; không CPU/interconnect toàn hệ thống.

Chạy lại: `tests/run.ps1`; compiler/testbench có thể cần chạy ngoài sandbox của agent do runtime Icarus. Kết quả ở `tests/results.txt`.

## Chưa thể làm trên bộ cài hiện tại

`tools/probe.tcl`: `add_instance cpu altera_nios2_gen2` trả `No module type named altera_nios2_gen2`.

Đã thử toàn bộ script tạo system: clock_source, RAM, custom peripheral và exports được công cụ nhận; lỗi còn lại đều do thiếu instance CPU và các kết nối phụ thuộc CPU. Log ở `cpu_generation_attempt.log`. Script cuối đã thêm kiểm tra dừng sớm khi CPU không tồn tại để không lưu system thiếu CPU.

Cần bộ cài có component Nios II Gen2 và Cyclone IV. Có compiler không đồng nghĩa có CPU IP generator. Script CPU chưa được generate end-to-end; phải kiểm tra schema tham số, SOPCINFO và port system sau khi có IP. Không giao SOF CPU giả hoặc đánh dấu full-system PASS.

## Checklist khi có công cụ/board

| Kiểm tra | Kỳ vọng |
|---|---|
| Generate CPU | Tiny/e ISA R1, debug memory nối cả hai master, vectors0x10000/0x10020 |
| Memory map | RAM64KiB@0x10000, peripheral@0x20000, debug@0x30000 |
| Quartus full compile | Không lỗi, không chân unassigned, xem licensing warning nếu có |
| TimeQuest | Ràng buộc/reset/synchronizers và timing50MHz được sign-off |
| JTAG | Nạp đúngSOF mới rồiELF; LCD hoạt động, R0 LED tắt |
| Echo | 9baud × 4data-width × 3parity × 2stop, giá trị byte trong phạm vi data-width |
| RX lỗi | Sai parity/stop bị bỏ, LED lỗi sáng, không ghi word lỗi lên LCD |
| LCD | Chuỗi>16ký tự chỉ lấy prefix, echo vẫn đủ; CRLF và gap500ms đúng |
| SW5/SW6 | Đổi STATUS/EXT, mỗi cạnh gửi đúng1report16byte, giữ switch cao không lặp |
| CTS stall | Không treo LCD/UI; lỗi sau2s, phục hồi truyền khi peer cho phép |
| Apply | Không cắt frame, pending baud/config chỉ có hiệu lực khi safe, Resume sớm được nhớ |
| Burst | Đo loss ở115200/230400 với RTS/CTS thực; nếu mất cần RX FIFO |
| Power cycle | Bản JTAG phải nạp lại ELF; chưa có flash boot |

RX slot một word, latency USB adapter, CPU/e và polling là rủi ro throughput thực tế chưa được các unit test loại trừ. Không dùng kết quả C model để cam kết zero-loss ở230400.
