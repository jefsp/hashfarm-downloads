@echo off
chcp 65001 >nul 2>&1
title go2mine - Atualizando agente...

:: Auto-elevate to admin
net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)

echo.
echo   =============================================
echo    go2mine - Atualizacao do agente
echo   =============================================
echo.
echo   Aguarde, atualizando automaticamente...
echo.

:: Stop agent
powershell -Command "Stop-ScheduledTask -TaskName 'go2mine hashfarm-agent' -ErrorAction SilentlyContinue" >nul 2>&1
taskkill /f /im python.exe /fi "WINDOWTITLE eq *agent*" >nul 2>&1
timeout /t 3 /nobreak >nul

:: Ensure install dir exists
if not exist "C:\hashfarm-agent" (
    echo   [ERRO] Pasta C:\hashfarm-agent nao encontrada.
    echo   Instale o agente primeiro em app.go2mine.com
    pause
    exit /b 1
)

:: Backup config
if exist "C:\hashfarm-agent\config.toml" copy /y "C:\hashfarm-agent\config.toml" "%TEMP%\go2mine-config.toml.bak" >nul

:: Download from app.go2mine.com (bypasses github.com SSL issues)
echo   Baixando ultima versao...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://app.go2mine.com/api/v1/farms/agent-package/hashfarm-agent-windows.zip' -OutFile '%TEMP%\go2mine-update.zip' -UseBasicParsing"
if %ERRORLEVEL% neq 0 (
    echo   [ERRO] Falha no download. Verifique sua conexao com a internet.
    pause
    exit /b 1
)

:: Extract
echo   Extraindo arquivos...
if exist "%TEMP%\go2mine-extract" rmdir /s /q "%TEMP%\go2mine-extract"
powershell -Command "Expand-Archive -Path '%TEMP%\go2mine-update.zip' -DestinationPath '%TEMP%\go2mine-extract' -Force"

:: Copy new files
echo   Aplicando atualizacao...
xcopy /s /y /q "%TEMP%\go2mine-extract\hashfarm-agent\*" "C:\hashfarm-agent\" >nul

:: Restore config
if exist "%TEMP%\go2mine-config.toml.bak" copy /y "%TEMP%\go2mine-config.toml.bak" "C:\hashfarm-agent\config.toml" >nul

:: Install dependencies
echo   Instalando dependencias...
"C:\hashfarm-agent\venv\Scripts\pip.exe" install --quiet --upgrade -r "C:\hashfarm-agent\requirements.txt" >nul 2>&1

:: Cleanup
del "%TEMP%\go2mine-update.zip" 2>nul
rmdir /s /q "%TEMP%\go2mine-extract" 2>nul
del "%TEMP%\go2mine-config.toml.bak" 2>nul

:: Restart agent
echo   Reiniciando agente...
powershell -Command "Start-ScheduledTask -TaskName 'go2mine hashfarm-agent' -ErrorAction SilentlyContinue" >nul 2>&1

:: Show version
for /f "tokens=2 delims==\" %%v in ('findstr /r "__version__" "C:\hashfarm-agent\agent\__init__.py"') do set VER=%%v
echo.
echo   =============================================
echo    Atualizado com sucesso!  %VER%
echo   =============================================
echo.
echo   O agente ja esta rodando. Pode fechar esta janela.
echo.
timeout /t 10
