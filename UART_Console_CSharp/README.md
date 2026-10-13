# UART Console C#

Mở UartConsole.exe. Mã nguồn UartConsole.cs; build lại bằng build.ps1 trong PowerShell. Dùng C# WinForms và System.IO.Ports.SerialPort của .NET Framework trên Windows, không phụ thuộc Python hoặc ctypes.

Cấu hình: đủ 9 baudrate của project; 5–8 data bits; None/Odd/Even; 1/2 stop bits; None, RTS/CTS, XON/XOFF hoặc kết hợp. FPGA hiện chỉ hỗ trợ hardware flow control, nên dùng None hoặc RTS/CTS. RTS thủ công khi không hardware handshake; DTR mặc định tắt. Đóng COM trong Hercules/Tera Term trước khi kết nối.

Gửi ASCII hoặc HEX, tùy chọn xuống dòng. RX chỉ chứa dữ liệu nhận; TX là byte đã giao thành công cho driver, không chứng minh đã nhận tại FPGA. Timeout có thể gửi một phần và không tự retry. Cần ngắt kết nối trước khi đổi frame. Cấu hình PC không tự đổi CFG trên board; vẫn cần Apply/Resume.

Mặc định 115200 / 8N1 / RTS/CTS. Lỗi mở COM hiển thị loại exception, nội dung và HRESULT. C# vẫn sử dụng driver Windows; đổi ngôn ngữ không đảm bảo khắc phục lỗi SetCommState của adapter. OPEN OK xác nhận thư viện mở cổng thành công, không phải phép đo frame trên dây. Driver có thể không báo lỗi parity cho từng byte; ứng dụng không chứng nhận tính hợp lệ parity của dữ liệu RX.

Mỗi vùng log tự xóa khi vượt 250000 ký tự. Lưu log lưu dữ liệu còn trên màn hình. Self-test: UartConsole.exe --self-test (không mở COM, kết quả trong self-test.txt).

COM10 trên máy này đã được chuyển sang driver CH340 3.7.2022.1 ngày 12/10/2026. Kiểm tra mở/cấu hình 12 tổ hợp tại 4800/115200 đạt; chi tiết ../CH340_Repair/REPAIR_RESULT.md. Có thêm `UartConsole.exe --check-port COM10` để thử mở/cấu hình mà không gửi dữ liệu (kết quả port-check.txt); đóng app UART khác trước. Chế độ kiểm tra đặt nhiều cấu hình COM tạm thời, vì vậy lần mở app tiếp theo phải chọn đúng cấu hình muốn dùng.
