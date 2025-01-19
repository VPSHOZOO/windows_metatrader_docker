@echo off
setlocal EnableDelayedExpansion

:: Set up logging
set LOGFILE=%~dp0install_log.txt
set TIMESTAMP=%date% %time%

:: Start logging
echo Installation started at %TIMESTAMP% > %LOGFILE%

:: Create a function to log messages
:log
echo %* >> %LOGFILE%
echo %*
goto :eof

:: Install Python
call :log "Installing Python 3.10..."
start /wait "" python-3.10.0-amd64.exe /quiet InstallAllUsers=1 PrependPath=1
if errorlevel 1 (
    call :log "Error: Python installation failed"
    goto :error
) else (
    call :log "Python installed successfully"
)

:: Wait for Python installation to complete
timeout /t 10 /nobreak

:: Install Python packages
call :log "Installing Python packages..."
python -m pip install --upgrade pip >> %LOGFILE% 2>&1
if errorlevel 1 (
    call :log "Error: Pip upgrade failed"
    goto :error
)

:: Install required packages
for %%p in (pyautogui pywinauto opencv-python pillow) do (
    call :log "Installing %%p..."
    pip install %%p >> %LOGFILE% 2>&1
    if errorlevel 1 (
        call :log "Error: Failed to install %%p"
        goto :error
    )
)

:: Success
call :log "All installations completed successfully"
goto :end

:error
call :log "Installation process failed. Check %LOGFILE% for details"
exit /b 1

:end
endlocal

xcopy "\\host.lan\Data\metatrader" "c:\metatrader" /E /I /C /Y
xcopy "\\host.lan\Data\experts" "c:\metatrader\experts" /E /I /C /Y
xcopy "\\host.lan\Data\scripts" "c:\metatrader\scripts" /E /I /C /Y

:: Run automation script
c:
cd metatrader
cd scripts
python -m venv venv
.\venv\Scripts\activate
pip install -r .\requirements.txt
python MT5_installer_automation.py

exit /b 0
