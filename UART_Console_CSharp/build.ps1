$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler not found.' }
& $compiler /nologo /target:winexe /platform:anycpu /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/out:$PSScriptRoot\UartConsole.exe" "$PSScriptRoot\UartConsole.cs"
if ($LASTEXITCODE -ne 0) { throw 'C# compilation failed.' }
Write-Output "Built $PSScriptRoot\UartConsole.exe"
