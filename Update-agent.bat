@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~s0\"' -Verb RunAs"
    exit /b
)

set TASK_NAME=go2mine hashfarm-agent
set INSTALL_DIR=C:\hashfarm-agent
set DOWNLOAD_URL=https://github.com/jefsp/hashfarm-downloads/raw/main/hashfarm-agent-windows.zip
set TMP_ZIP=%TEMP%\hashfarm-agent-update.zip
set TMP_DIR=%TEMP%\hashfarm-agent-update

echo.
echo  Atualizando agente go2mine...
echo  ============================================
echo.

echo [1/5] Parando o agente...
schtasks /End /TN "%TASK_NAME%" >nul 2>&1
timeout /t 3 /nobreak >nul
echo        OK

echo [2/5] Baixando nova versao...
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TMP_ZIP%' -UseBasicParsing"
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao baixar. Verifique sua conexao com a internet.
    pause
    exit /b 1
)
echo        OK

echo [3/5] Extraindo arquivos...
if exist "%TMP_DIR%" rd /s /q "%TMP_DIR%"
powershell -Command "Expand-Archive -Path '%TMP_ZIP%' -DestinationPath '%TMP_DIR%' -Force"
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao extrair o ZIP.
    pause
    exit /b 1
)
echo        OK

echo [4/5] Atualizando arquivos do agente (config.toml preservado)...
set EXTRACTED=
for /d %%i in ("%TMP_DIR%\*") do set EXTRACTED=%%i
if "%EXTRACTED%"=="" set EXTRACTED=%TMP_DIR%

if not exist "%EXTRACTED%\agent" (
    echo [ERRO] Estrutura do ZIP inesperada.
    pause
    exit /b 1
)

xcopy /e /y /q "%EXTRACTED%\agent" "%INSTALL_DIR%\agent\" >nul
xcopy /y /q "%EXTRACTED%\requirements.txt" "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\_install.ps1"        xcopy /y /q "%EXTRACTED%\_install.ps1"        "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\_uninstall.ps1"      xcopy /y /q "%EXTRACTED%\_uninstall.ps1"      "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\Install-agent.bat"   xcopy /y /q "%EXTRACTED%\Install-agent.bat"   "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\Uninstall-agent.bat" xcopy /y /q "%EXTRACTED%\Uninstall-agent.bat" "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\Restart-agent.bat"   xcopy /y /q "%EXTRACTED%\Restart-agent.bat"   "%INSTALL_DIR%\" >nul
if exist "%EXTRACTED%\Update-agent.bat"    xcopy /y /q "%EXTRACTED%\Update-agent.bat"    "%INSTALL_DIR%\" >nul

"%INSTALL_DIR%\venv\Scripts\pip.exe" install --quiet --upgrade -r "%INSTALL_DIR%\requirements.txt" >nul 2>&1

rd /s /q "%TMP_DIR%" >nul 2>&1
del /q "%TMP_ZIP%" >nul 2>&1
echo        OK

echo [5/5] Reiniciando o agente...
schtasks /Run /TN "%TASK_NAME%"
if %errorlevel% neq 0 (
    echo [ERRO] Nao foi possivel reiniciar o agente.
) else (
    echo        OK
)

echo.
echo  ============================================
echo  Atualizacao concluida!
echo  Acesse https://app.go2mine.com para confirmar
echo  que o agente esta online.
echo  ============================================
echo.
pause
