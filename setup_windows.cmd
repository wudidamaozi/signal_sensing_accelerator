@echo off
setlocal
cd /d "%~dp0"
python -X utf8 build\setup_environment.py
if errorlevel 1 exit /b 1
echo Ready. Run start_web.cmd to open the demo.
