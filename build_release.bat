@echo off
setlocal enabledelayedexpansion

:: Constroi em staging e so troca dist depois de validar todo o release.
if not exist boss.json (
  echo [ERRO] Execute este script na raiz do repositorio Boss4D.
  exit /b 1
)
if not exist src\Boss4D.dpr (
  echo [ERRO] Workspace Boss4D invalido.
  exit /b 1
)
set "OUTPUT_DIR=dist.new"
set "BACKUP_DIR=dist.previous"
if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!"
if exist "!OUTPUT_DIR!" (
  echo [ERRO] Nao foi possivel limpar o staging !OUTPUT_DIR!.
  exit /b 1
)
mkdir "!OUTPUT_DIR!\bin"
mkdir "!OUTPUT_DIR!\plugins"

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
mkdir "!OUTPUT_DIR!\bin\Win32"
pushd src
call dcc32 -B -Q -E"..\!OUTPUT_DIR!\bin\Win32" Boss4D.dpr
set "BUILD_EXIT=!ERRORLEVEL!"
popd
if not "!BUILD_EXIT!"=="0" goto BuildFailed
copy "!OUTPUT_DIR!\bin\Win32\Boss4D.exe" "!OUTPUT_DIR!\bin\boss4d.exe"
if errorlevel 1 goto BuildFailed

echo Compilando CLI Win64...
mkdir "!OUTPUT_DIR!\bin\Win64"
pushd src
call dcc64 -B -Q -E"..\!OUTPUT_DIR!\bin\Win64" Boss4D.dpr
set "BUILD_EXIT=!ERRORLEVEL!"
popd
if not "!BUILD_EXIT!"=="0" goto BuildFailed
copy "!OUTPUT_DIR!\bin\Win64\Boss4D.exe" "!OUTPUT_DIR!\bin\boss4d_x64.exe"
if errorlevel 1 goto BuildFailed

:: Compila a GUI Win32 e Win64
echo Compilando GUI Win32...
pushd src\GUI
call dcc32 -B -Q -E"..\..\!OUTPUT_DIR!\bin\Win32" Boss4D.GUI.dpr
set "BUILD_EXIT=!ERRORLEVEL!"
popd
if not "!BUILD_EXIT!"=="0" goto BuildFailed
copy "!OUTPUT_DIR!\bin\Win32\Boss4D.GUI.exe" "!OUTPUT_DIR!\bin\Boss4D.GUI.exe"
if errorlevel 1 goto BuildFailed

echo Compilando GUI Win64...
pushd src\GUI
call dcc64 -B -Q -E"..\..\!OUTPUT_DIR!\bin\Win64" Boss4D.GUI.dpr
set "BUILD_EXIT=!ERRORLEVEL!"
popd
if not "!BUILD_EXIT!"=="0" goto BuildFailed
copy "!OUTPUT_DIR!\bin\Win64\Boss4D.GUI.exe" "!OUTPUT_DIR!\bin\Boss4D.GUI_x64.exe"
if errorlevel 1 goto BuildFailed

:: Limpa subpastas temporarias
rmdir /s /q "!OUTPUT_DIR!\bin\Win32"
rmdir /s /q "!OUTPUT_DIR!\bin\Win64"

:: Gera os SBOMs reproduziveis do proprio Boss4D
mkdir "!OUTPUT_DIR!\sbom" 2>nul
call "!OUTPUT_DIR!\bin\boss4d.exe" sbom --format cyclonedx --strict --validate --lock-only --reproducible --output "!OUTPUT_DIR!\sbom\boss4d.cdx.json"
if errorlevel 1 goto BuildFailed
call "!OUTPUT_DIR!\bin\boss4d.exe" sbom --format spdx --strict --validate --lock-only --reproducible --output "!OUTPUT_DIR!\sbom\boss4d.spdx.json"
if errorlevel 1 goto BuildFailed

:: Compilando os Plugins de IDE para cada versao suportada
mkdir "!OUTPUT_DIR!\plugins\11" 2>nul
mkdir "!OUTPUT_DIR!\plugins\12" 2>nul
mkdir "!OUTPUT_DIR!\plugins\13" 2>nul

:: Delphi 11 (BDS 22.0)
set "D11_PATH="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Embarcadero\BDS\22.0" /v RootDir 2^>nul') do set "D11_PATH=%%B"
if not defined D11_PATH goto SkipD11
echo Compilando plugin para Delphi 11...
setlocal
pushd src\IDE
call "%D11_PATH%\bin\rsvars.bat"
brcc32 Boss4D.IDE.Plugin.rc
call dcc32 -B -Q -LUrtl -LUvcl -LUdesignide -DIDE_PLUGIN -U"%D11_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl "!OUTPUT_DIR!\plugins\11\Boss4D.IDE.Plugin.bpl"
if errorlevel 1 goto BuildFailed
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
call dcc32 -B -Q -LUrtl -LUvcl -LUdesignide -DIDE_PLUGIN -U"%D12_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl "!OUTPUT_DIR!\plugins\12\Boss4D.IDE.Plugin.bpl"
if errorlevel 1 goto BuildFailed
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
call dcc32 -B -Q -LUrtl -LUvcl -LUdesignide -DIDE_PLUGIN -U"%D13_PATH%\lib\Win32\release" Boss4D.IDE.Plugin.dpk
popd
copy src\IDE\Boss4D.IDE.Plugin.bpl "!OUTPUT_DIR!\plugins\13\Boss4D.IDE.Plugin.bpl"
if errorlevel 1 goto BuildFailed
del src\IDE\Boss4D.IDE.Plugin.bpl 2>nul
del src\IDE\Boss4D.IDE.Plugin.res 2>nul
endlocal
:SkipD13

if exist "!BACKUP_DIR!" rmdir /s /q "!BACKUP_DIR!"
if exist dist move dist "!BACKUP_DIR!" >nul
move "!OUTPUT_DIR!" dist >nul
if errorlevel 1 (
  if exist "!BACKUP_DIR!" move "!BACKUP_DIR!" dist >nul
  echo [ERRO] Falha ao promover staging para dist.
  exit /b 1
)
if exist "!BACKUP_DIR!" rmdir /s /q "!BACKUP_DIR!"
echo [OK] Pasta dist promovida atomicamente e pronta para o Inno Setup!
exit /b 0

:BuildFailed
echo [ERRO] Build de release falhou. A pasta dist anterior foi preservada.
if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!"
exit /b 1
