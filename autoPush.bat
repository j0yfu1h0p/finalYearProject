@echo off
REM Auto Git Add, Commit, and Push (no input needed)

:: Generate commit message with random number
set /a rand=%random%
set commitmsg=auto-commit-%rand%

:: Run git commands
git add .
git commit -m "%commitmsg%"
git push origin main

echo Commit pushed with message: %commitmsg%

pause
