@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~s0\"' -Verb RunAs"
    exit /b
)

set TASK_NAME=go2mine hashfarm-agent
set INSTALL_DIR=C:\hashfarm-agent
set DOWNLOAD_URL=https://github.com/jefsp/hashfarm-downloads/releases/latest/download/hashfarm-agent-windows.zip
set TMP_ZIP=C:\Temp\hf-update.zip
set TMP_DIR=C:\Temp\hf-update

echo.
echo  Atualizando agente go2mine...
echo  ============================================
echo.

echo [1/5] Parando o agente...
schtasks /End /TN "%TASK_NAME%" >nul 2>&1
timeout /t 2 /nobreak >nul
powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Stop-Process -Force" >nul 2>&1
timeout /t 2 /nobreak >nul
echo        OK

echo [2/5] Baixando nova versao...
if not exist "C:\Temp" mkdir "C:\Temp"
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
set EXTRACTED=%TMP_DIR%
if not exist "%TMP_DIR%\agent" (
    for /d %%i in ("%TMP_DIR%\*") do (
        if exist "%%i\agent" set EXTRACTED=%%i
    )
)
if not exist "%EXTRACTED%\agent" (
    echo [ERRO] Estrutura do ZIP inesperada.
    pause
    exit /b 1
)

xcopy /e /y /q "%EXTRACTED%\agent" "%INSTALL_DIR%\agent\" >nul
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao copiar arquivos do agente.
    pause
    exit /b 1
)
if exist "%EXTRACTED%\requirements.txt"   (xcopy /y /q "%EXTRACTED%\requirements.txt"   "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\_install.ps1"        (xcopy /y /q "%EXTRACTED%\_install.ps1"        "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\_uninstall.ps1"      (xcopy /y /q "%EXTRACTED%\_uninstall.ps1"      "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\Install-agent.bat"   (xcopy /y /q "%EXTRACTED%\Install-agent.bat"   "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\Uninstall-agent.bat" (xcopy /y /q "%EXTRACTED%\Uninstall-agent.bat" "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\Restart-agent.bat"   (xcopy /y /q "%EXTRACTED%\Restart-agent.bat"   "%INSTALL_DIR%\" >nul 2>&1)
if exist "%EXTRACTED%\Update-agent.bat"    (xcopy /y /q "%EXTRACTED%\Update-agent.bat"    "%INSTALL_DIR%\" >nul 2>&1)

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

set NEW_VERSION=
for /f "tokens=2 delims== " %%v in ('findstr "__version__" "%INSTALL_DIR%\agent\__init__.py" 2^>nul') do set NEW_VERSION=%%~v

echo.
echo  ============================================
echo  Atualizacao concluida!
if defined NEW_VERSION (
    echo  Versao instalada: v%NEW_VERSION%
) else (
    echo  Versao instalada: desconhecida
)
echo  Acesse https://app.go2mine.com para confirmar
echo  que o agente esta online.
echo  ============================================
echo.
pause
