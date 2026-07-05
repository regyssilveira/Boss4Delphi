@echo off
setlocal enabledelayedexpansion

:: Limpa a pasta dist
if exist dist rmdir /s /q dist
mkdir dist\bin
mkdir dist\plugins

:: Delphi 13 (Florence) - Versao padrao usada para compilar a CLI e a GUI
set "D13_PATH="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Embarcadero\BDS\37.0" /v RootDir 2^>nul') do set "D13_PATH=%%B"

if not defined D13_PATH (
  :: Fallback para Delphi 12 se Delphi 13 nao for encontrado para o build principal
  for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Embarcadero\BDS\23.0" /v RootDir 2^>nul') do set "D13_PATH=%%B"
)

if not defined D13_PATH (
  echo [ERRO] Nao foi possivel localizar uma instalacao do Delphi 12 ou 13 para compilar a CLI/GUI!
  exit /b 1
)

echo Compilando CLI e GUI de producao usando: !D13_PATH!
call "!D13_PATH!\bin\rsvars.bat"

:: Compila a CLI Win32 e Win64
echo Compilando CLI Win32...
mkdir dist\bin\Win32
call dcc32 -B -Q -U"src\Core\Domain" -U"src\Core\Ports" -U"src\Core\Services" -U"src\Adapters\Json" -U"src\Adapters\Http" -U"src\Adapters\Git" -U"src\Adapters\Registry" -U"src\Adapters\Compiler" -U"src\Adapters\Logger" -U"src\CLI" -E"dist\bin\Win32" src\Boss4D.dpr
copy dist\bin\Win32\Boss4D.exe dist\bin\boss4d.exe

echo Compilando CLI Win64...
mkdir dist\bin\Win64
call dcc64 -B -Q -U"src\Core\Domain" -U"src\Core\Ports" -U"src\Core\Services" -U"src\Adapters\Json" -U"src\Adapters\Http" -U"src\Adapters\Git" -U"src\Adapters\Registry" -U"src\Adapters\Compiler" -U"src\Adapters\Logger" -U"src\CLI" -E"dist\bin\Win64" src\Boss4D.dpr
copy dist\bin\Win64\Boss4D.exe dist\bin\boss4d_x64.exe

:: Compila a GUI Win32 e Win64
echo Compilando GUI Win32...
call dcc32 -B -Q -U"src\Core\Domain" -U"src\Core\Ports" -U"src\Core\Services" -U"src\Adapters\Json" -U"src\Adapters\Http" -U"src\Adapters\Git" -U"src\Adapters\Registry" -U"src\Adapters\Compiler" -U"src\Adapters\Logger" -U"src\CLI" -E"dist\bin\Win32" src\GUI\Boss4D.GUI.dpr
copy dist\bin\Win32\Boss4D.GUI.exe dist\bin\Boss4D.GUI.exe

echo Compilando GUI Win64...
call dcc64 -B -Q -U"src\Core\Domain" -U"src\Core\Ports" -U"src\Core\Services" -U"src\Adapters\Json" -U"src\Adapters\Http" -U"src\Adapters\Git" -U"src\Adapters\Registry" -U"src\Adapters\Compiler" -U"src\Adapters\Logger" -U"src\CLI" -E"dist\bin\Win64" src\GUI\Boss4D.GUI.dpr
copy dist\bin\Win64\Boss4D.GUI.exe dist\bin\Boss4D.GUI_x64.exe

:: Limpa subpastas temporarias
rmdir /s /q dist\bin\Win32
rmdir /s /q dist\bin\Win64

:: Compilando os Plugins de IDE para cada versao suportada
mkdir dist\plugins\11 2>nul
mkdir dist\plugins\12 2>nul
mkdir dist\plugins\13 2>nul

:: Delphi 11 (BDS 22.0)
set "D11_PATH="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Embarcadero\BDS\22.0" /v RootDir 2^>nul') do set "D11_PATH=%%B"
if not defined D11_PATH goto SkipD11
echo Compilando plugin para Delphi 11...
setlocal
pushd src\IDE
call "%D11_PATH%\bin\rsvars.bat"
brcc32 Boss4D.IDE.Plugin.rc
call dcc32 -B -Q -LUdesignide -DIDE_PLUGIN -U"%D11_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl dist\plugins\11\Boss4D.IDE.Plugin.bpl
del src\IDE\Boss4D.IDE.Plugin.bpl 2>nul
del src\IDE\Boss4D.IDE.Plugin.res 2>nul
endlocal
:SkipD11

:: Delphi 12 (BDS 23.0)
set "D12_PATH="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Embarcadero\BDS\23.0" /v RootDir 2^>nul') do set "D12_PATH=%%B"
if not defined D12_PATH goto SkipD12
echo Compilando plugin para Delphi 12...
setlocal
pushd src\IDE
call "%D12_PATH%\bin\rsvars.bat"
brcc32 Boss4D.IDE.Plugin.rc
call dcc32 -B -Q -LUdesignide -DIDE_PLUGIN -U"%D12_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl dist\plugins\12\Boss4D.IDE.Plugin.bpl
del src\IDE\Boss4D.IDE.Plugin.bpl 2>nul
del src\IDE\Boss4D.IDE.Plugin.res 2>nul
endlocal
:SkipD12

:: Delphi 13 (BDS 37.0)
if not defined D13_PATH goto SkipD13
echo Compilando plugin para Delphi 13...
setlocal
pushd src\IDE
call "%D13_PATH%\bin\rsvars.bat"
brcc32 Boss4D.IDE.Plugin.rc
call dcc32 -B -Q -LUdesignide -DIDE_PLUGIN -U"%D13_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl dist\plugins\13\Boss4D.IDE.Plugin.bpl
del src\IDE\Boss4D.IDE.Plugin.bpl 2>nul
del src\IDE\Boss4D.IDE.Plugin.res 2>nul
endlocal
:SkipD13

echo [OK] Pasta dist populada e pronta para o Inno Setup!
