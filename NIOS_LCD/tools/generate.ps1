param([Parameter(Mandatory=$true)][string]$QuartusRoot)
$ErrorActionPreference='Stop'
Push-Location "$PSScriptRoot/../quartus"
try {
  $ipPath=(Resolve-Path ../ip).Path.Replace('\','/')
  $search='--search-path='+$ipPath+',$'
  & "$QuartusRoot/sopc_builder/bin/qsys-script.exe" $search --script=../tools/create_system.tcl
  if ($LASTEXITCODE) { throw 'Cannot create CPU system. Nios II Gen2 IP must be installed; see README.' }
  & "$QuartusRoot/sopc_builder/bin/qsys-generate.exe" $search nios_uart_system.qsys --synthesis=VERILOG
  if ($LASTEXITCODE) { throw 'HDL generation failed' }
  & "$QuartusRoot/bin64/quartus_sh.exe" --flow compile uart_nios
  if ($LASTEXITCODE) { throw 'Quartus compilation failed' }
} finally { Pop-Location }
