$ErrorActionPreference='Stop'
$iverilog=Join-Path $PSScriptRoot '../../RTL/tools/iverilog/ucrt64/bin/iverilog.exe'
$vvp=Join-Path $PSScriptRoot '../../RTL/tools/iverilog/ucrt64/bin/vvp.exe'
$env:PATH='C:\msys64\ucrt64\bin;'+$env:PATH
Push-Location $PSScriptRoot
try {
  & gcc -std=c99 -Wall -Wextra -Werror -O2 -o test_app.exe test_app.c ../firmware/app.c
  if ($LASTEXITCODE) { throw 'Host C compilation failed' }
  & ./test_app.exe
  if ($LASTEXITCODE) { throw 'Firmware model tests failed' }
  $rtl=@('../rtl/avalon_apb_bridge.v','../rtl/lcd_text.v','../rtl/uart_cpu_peripheral.v')
  $rtl+=@(Get-ChildItem ../../RTL/rtl/*.v | Where-Object Name -notmatch 'apb_echo_master|apb_transaction_master' | ForEach-Object FullName)
  & $iverilog -g2001 -Wall -I ../../RTL/rtl -s uart_cpu_peripheral -o compile.vvp @rtl
  if ($LASTEXITCODE) { throw 'Verilog-2001 compile failed' }
  foreach($t in @('tb_bridge','tb_peripheral','tb_lcd')) {
    & $iverilog -g2012 -I ../../RTL/rtl -s $t -o "$t.vvp" @rtl "$t.sv"
    if ($LASTEXITCODE) { throw "$t compile failed" }
    & $vvp "$t.vvp"
    if ($LASTEXITCODE) { throw "$t simulation failed" }
  }
} finally { Pop-Location }
