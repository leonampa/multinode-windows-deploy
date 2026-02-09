@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM
REM === Automated WIM Deployment Script for WinPE (UEFI/GPT) ===
REM
REM FINAL FINAL FINAL FIX: Replaced all inline short-circuit logic (&& / ||) 
REM with the ancient but 100% reliable GOTO label error handling to bypass 
REM the WinPE parser bug ("- was unexpected").
REM
SET temp_list_script=list_disk_script.txt

ECHO =========================================================
ECHO           CUSTOM WINDOWS WIM DEPLOYMENT UTILITY
ECHO =========================================================
ECHO.

REM -------------------------------------------
REM STEP 1: List Disks and Prompt for Selection
REM -------------------------------------------
CHCP 437 >NUL
ECHO.
ECHO Attempting to list all available disks... (Step 1: Enters diskpart, runs list disk)
ECHO ---------------------------------------
(
ECHO list disk
ECHO exit
) > "%temp_list_script%"
CALL diskpart /s "%temp_list_script%"
ECHO ---------------------------------------
DEL "%temp_list_script%" 2>NUL
:ASK_DISK
ECHO.
SET /P disk_num="ENTER THE NUMBER of the DISK to install Windows on (e.g., 0): "
IF NOT DEFINED disk_num GOTO ASK_DISK
IF /I "!disk_num!" EQU "" GOTO ASK_DISK

REM -------------------------------------------
REM STEP 2: Identify WIM File Location
REM -------------------------------------------
:ASK_WIM_DRIVE
ECHO.
SET /P wim_drive="ENTER THE DRIVE LETTER of the USB/Flash Drive with install.wim (e.g., E): "
IF NOT DEFINED wim_drive GOTO ASK_WIM_DRIVE
IF /I "!wim_drive!" EQU "" GOTO ASK_WIM_DRIVE
SET wim_drive=!wim_drive:~0,1!
IF NOT EXIST "!wim_drive!:\install.wim" (
    ECHO.
    ECHO ERROR: install.wim not found at !wim_drive!:\install.wim. Check the drive letter and file.
    GOTO ASK_WIM_DRIVE
)
SET diskpart_script_path="!wim_drive!:\diskpart_script.txt"
SET remount_script_path="!wim_drive!:\remount_script.txt"

REM -------------------------------------------
REM STEP 3: Partition and Format the Target Disk (GPT/UEFI)
REM -------------------------------------------
ECHO.
ECHO Preparing Disk !disk_num! for UEFI/GPT deployment.
ECHO All existing data on this disk will be ERASED.
PAUSE

REM Create the diskpart partitioning script (Step 4)
CHCP 437 >NUL
ECHO SELECT DISK !disk_num! > !diskpart_script_path!
ECHO CLEAN >> !diskpart_script_path!
ECHO CONVERT GPT >> !diskpart_script_path!
ECHO REM 1. EFI System Partition (100MB) >> !diskpart_script_path!
ECHO CREATE PARTITION EFI SIZE=100 >> !diskpart_script_path!
ECHO FORMAT QUICK FS=FAT32 LABEL="System" >> !diskpart_script_path!
ECHO ASSIGN LETTER=S >> !diskpart_script_path!
ECHO REM 2. Microsoft Reserved Partition (16MB) >> !diskpart_script_path!
ECHO CREATE PARTITION MSR SIZE=16 >> !diskpart_script_path!
ECHO REM 3. Windows Primary Partition (Main OS) >> !diskpart_script_path!
ECHO CREATE PARTITION PRIMARY >> !diskpart_script_path!
ECHO FORMAT QUICK FS=NTFS LABEL="Windows" >> !diskpart_script_path!
ECHO ASSIGN LETTER=W >> !diskpart_script_path!
ECHO EXIT >> !diskpart_script_path!

ECHO Running DiskPart to partition disk !disk_num!...
CALL diskpart /s !diskpart_script_path!

REM --- DISKPART ERROR CHECK AND CLEANUP ---
DEL !diskpart_script_path! 2>NUL
IF ERRORLEVEL 1 GOTO DISKPART_FAILED
ECHO Disk partitioning complete. Windows primary partition assigned letter W.
GOTO DISKPART_SUCCESS

:DISKPART_FAILED
ECHO.
ECHO CRITICAL ERROR: DiskPart failed to partition the disk. Exiting.
PAUSE
EXIT /B
:DISKPART_SUCCESS
REM -------------------------------------------------

REM -------------------------------------------
REM STEP 4: Apply the WIM Image using DISM
REM -------------------------------------------
ECHO.
ECHO Applying image from !wim_drive!:\install.wim to W:\...
dism /Apply-Image /ImageFile:"!wim_drive!:\install.wim" /Index:1 /ApplyDir:W:\ /CheckIntegrity
IF ERRORLEVEL 1 GOTO DISM_FAILED
ECHO Image application complete.
GOTO DISM_SUCCESS

:DISM_FAILED
ECHO.
ECHO CRITICAL ERROR: DISM failed (Error code !ERRORLEVEL!). Image application failed.
ECHO Check the DISM log file for more details.
PAUSE
EXIT /B
:DISM_SUCCESS
REM ---------------------------------

REM -------------------------------------------
REM STEP 5: Re-Assign Drive Letters (Hardening the Boot Process)
REM -------------------------------------------
ECHO.
ECHO Re-assigning drive letters W and S to ensure BCDBOOT can find the boot partition...
CHCP 437 >NUL
ECHO SELECT DISK !disk_num! > !remount_script_path!
ECHO SELECT PARTITION 1 >> !remount_script_path!
ECHO ASSIGN LETTER=S >> !remount_script_path!
ECHO SELECT PARTITION 3 >> !remount_script_path!
ECHO ASSIGN LETTER=W >> !remount_script_path!
ECHO EXIT >> !remount_script_path!

CALL diskpart /s !remount_script_path!
DEL !remount_script_path! 2>NUL
ECHO Drive letters W and S confirmed.

REM -------------------------------------------
REM STEP 6: Create Boot Files
REM -------------------------------------------
ECHO.
ECHO Creating boot configuration files for UEFI...
W:\Windows\System32\bcdboot W:\Windows /s S: /f UEFI
IF ERRORLEVEL 1 GOTO BCDBOOT_WARNING
ECHO Boot files created successfully. Windows Boot Manager should now be available.
GOTO BCDBOOT_SUCCESS

:BCDBOOT_WARNING
ECHO.
ECHO WARNING: BCDBOOT failed (Error code !ERRORLEVEL!). The system might not boot.
PAUSE
:BCDBOOT_SUCCESS
REM ------------------------------------

REM -------------------------------------------
REM CLEANUP AND REBOOT
REM -------------------------------------------
ECHO.
ECHO Cleanup complete. The new Windows installation is ready.
ECHO.
ECHO The PC will now reboot to start the Windows Out-of-Box Experience (OOBE).
ECHO *** REMOVE THE USB DRIVE NOW! ***
ECHO.
TIMEOUT /T 10

REM Step 7: Reboots the PC
wpeutil reboot

ENDLOCAL