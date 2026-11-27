@echo off
REM Builds RacingCar.exe with MASM 6.15 (ML.EXE + LINK32.EXE) and the Irvine32 library.
REM Run this file from the folder that holds RacingCar.asm.
REM Change the next line if MASM 6.15 / Irvine is installed in another folder.
SET MASMDIR=C:\Masm615

SET INCLUDE=%MASMDIR%\INCLUDE;%INCLUDE%
SET LIB=%MASMDIR%\LIB;%LIB%
SET PATH=%MASMDIR%;%PATH%

ML -nologo -c -coff -Zi RacingCar.asm
if errorlevel 1 goto failed

LINK32 RacingCar.obj irvine32.lib kernel32.lib /NOLOGO /SUBSYSTEM:CONSOLE /DEBUG
if errorlevel 1 goto failed

echo.
echo Build finished: RacingCar.exe
goto done

:failed
echo.
echo Build FAILED - check the messages above.

:done
