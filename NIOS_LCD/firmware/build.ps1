param([string]$ToolBin='D:\DATA\Quartus_lite\nios2eds\bin\gnu\H-x86_64-mingw32\bin')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
  New-Item -ItemType Directory -Force build | Out-Null
  & "$ToolBin/nios2-elf-gcc.exe" -march=r1 -mno-hw-mul -mno-hw-div -G0 -Os -Wall -Wextra -Werror -ffreestanding -fno-builtin -nostdlib '-Wl,-T,linker.ld,-Map,build/uart_lcd.map' -o build/uart_lcd.elf start.S platform.c app.c -lgcc
  if ($LASTEXITCODE) { throw 'Nios II firmware build failed' }
  & "$ToolBin/nios2-elf-size.exe" build/uart_lcd.elf
  if ($LASTEXITCODE) { throw 'size failed' }
} finally { Pop-Location }
