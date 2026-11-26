@echo off
setlocal
pushd "%~dp0"
where py >nul 2>&1
if errorlevel 1 goto via_python
py -3 serve_game.py
goto finished
:via_python
python serve_game.py
:finished
if errorlevel 1 pause
popd
