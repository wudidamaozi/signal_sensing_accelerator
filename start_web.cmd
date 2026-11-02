@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Please run setup_windows.cmd first.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -X utf8 build\run_web.py --backend software --open
