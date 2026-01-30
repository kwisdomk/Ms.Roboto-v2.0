# Mr. Roboto v2.0 - Testing Guide

## 🧪 How to Test Mr. Roboto

This guide covers all available tests for the current implementation (Sprint 1 & 2).

---

## Prerequisites

- Windows 10/11 (x86 or x64)
- PowerShell 5.1 or later
- Internet connection (for dependency downloads)
- Administrator privileges (optional, for some tests)

---

## Test 1: Basic Initialization ✅ PASSED

**What it tests:** Environment setup, logging, configuration

**Command:**
```powershell
cd q:/mr.roboto
.\roboto.ps1
```

**Expected Output:**
```
Created default configuration file
[2026-01-31 00:57:43] [INFO] === Mr. Roboto v2.0.0 ===
[2026-01-31 00:57:43] [INFO] Session started at 2026-01-31 00:57:43
[2026-01-31 00:57:43] [INFO] PowerShell version: 5.1.x
[2026-01-31 00:57:43] [INFO] Operating System: Microsoft Windows NT...
[2026-01-31 00:57:43] [INFO] Environment initialized successfully
[2026-01-31 00:57:43] [INFO] Detecting hardware capabilities...
[2026-01-31 00:57:43] [DEBUG] Architecture: x64
[2026-01-31 00:57:44] [INFO] GPU detected: [Your GPU Name]
[2026-01-31 00:57:44] [INFO] Selected encoder: [h264_nvenc/h264_qsv/h264_amf/libx264]
Initialization complete. Ready to acquire media.
```

**What to verify:**
- ✅ Directories created: `bin/`, `downloads/`, `logs/`, `state/`, `cache/`, `metadata/`
- ✅ `config.json` created with default settings
- ✅ Log file created in `logs/session_YYYYMMDD_HHMMSS.log`
- ✅ GPU detected correctly (or "None (Software)" if no GPU)
- ✅ Correct encoder selected based on GPU

---

## Test 2: Dependency Download (First Run)

**What it tests:** Auto-download of yt-dlp and FFmpeg

**Command:**
```powershell
# Delete binaries first to test download
Remove-Item -Path "q:/mr.roboto/bin" -Recurse -Force -ErrorAction SilentlyContinue
.\roboto.ps1
```

**Expected Output:**
```
[INFO] Checking dependencies...
[INFO] yt-dlp not found, will download
[INFO] FFmpeg not found, will download

Downloading required dependencies...
This may take a minute on first run.

  Downloading yt-dlp... Done!
  Downloading FFmpeg... Downloaded!
  Extracting FFmpeg... Done!
[INFO] Dependency check complete
```

**What to verify:**
- ✅ `bin/x64/yt-dlp.exe` downloaded (or `bin/x86/` on 32-bit)
- ✅ `bin/x64/ffmpeg.exe` downloaded
- ✅ `bin/x64/ffprobe.exe` downloaded
- ✅ Files are executable (not corrupted)
- ✅ Download completes without errors

**Time:** ~30-60 seconds depending on internet speed

---

## Test 3: Offline Mode

**What it tests:** Skip dependency checks and updates

**Command:**
```powershell
.\roboto.ps1 -OfflineMode
```

**Expected Output:**
```
[WARN] Offline mode active - skipping dependency installation
[DEBUG] yt-dlp auto-update disabled
```

**What to verify:**
- ✅ No internet requests made
- ✅ Script runs with existing binaries
- ✅ Warning logged about offline mode

---

## Test 4: Configuration Validation

**What it tests:** Config file structure and defaults

**Command:**
```powershell
Get-Content q:/mr.roboto/config.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Expected Output:**
```json
{
  "version": "2.0.0",
  "settings": {
    "defaultQuality": "high",
    "autoUpdate": true,
    "offlineMode": false,
    "notifications": true,
    "preferredContainer": "mp4",
    "libraryMode": false
  },
  "profiles": {
    "ultra": { ... },
    "high": { ... },
    "mobile": { ... }
  },
  "binaries": { ... }
}
```

**What to verify:**
- ✅ Valid JSON structure
- ✅ All three profiles present (ultra, high, mobile)
- ✅ Binary URLs are valid GitHub links
- ✅ Settings have correct defaults

---

## Test 5: Logging System

**What it tests:** Log file creation and rotation

**Command:**
```powershell
# Run script multiple times
.\roboto.ps1
.\roboto.ps1
.\roboto.ps1

# Check logs
Get-ChildItem q:/mr.roboto/logs/
```

**Expected Output:**
```
session_20260131_005743.log
session_20260131_010215.log
session_20260131_010530.log
```

**What to verify:**
- ✅ New log file created per session
- ✅ Log files contain timestamped entries
- ✅ Different log levels present (INFO, DEBUG, WARN, ERROR)
- ✅ Old logs (>30 days) are automatically deleted

**View a log:**
```powershell
Get-Content q:/mr.roboto/logs/session_*.log | Select-Object -Last 20
```

---

## Test 6: GPU Detection

**What it tests:** Hardware capability detection

**Command:**
```powershell
.\roboto.ps1
```

**Expected Results by GPU Type:**

| GPU Type | Expected Encoder | Log Message |
|----------|-----------------|-------------|
| NVIDIA GeForce/RTX | `h264_nvenc` | "GPU detected: NVIDIA..." |
| Intel HD/UHD Graphics | `h264_qsv` | "GPU detected: Intel..." |
| AMD Radeon | `h264_amf` | "GPU detected: AMD..." |
| No GPU / VM | `libx264` | "No dedicated GPU detected" |

**What to verify:**
- ✅ Correct GPU name displayed
- ✅ Appropriate encoder selected
- ✅ Architecture detected (x64 or x86)

---

## Test 7: Binary Version Check

**What it tests:** Installed binary versions

**Command:**
```powershell
# Check yt-dlp version
& "q:/mr.roboto/bin/x64/yt-dlp.exe" --version

# Check FFmpeg version
& "q:/mr.roboto/bin/x64/ffmpeg.exe" -version
```

**Expected Output:**
```
# yt-dlp
2024.xx.xx

# FFmpeg
ffmpeg version N-xxxxx-gxxxxxxxx
```

**What to verify:**
- ✅ Binaries are executable
- ✅ Versions are recent (not corrupted downloads)
- ✅ FFmpeg includes all codecs

---

## Test 8: Error Handling

**What it tests:** Graceful error handling

**Test 8a: Corrupted Config**
```powershell
# Corrupt the config
Set-Content q:/mr.roboto/config.json -Value "{ invalid json"
.\roboto.ps1
```

**Expected:** Error message with details, script exits gracefully

**Test 8b: No Write Permissions**
```powershell
# Make logs directory read-only
Set-ItemProperty q:/mr.roboto/logs -Name IsReadOnly -Value $true
.\roboto.ps1
```

**Expected:** Warning about log write failure, script continues

---

## Test 9: Command-Line Parameters

**What it tests:** Parameter handling (for future use)

**Command:**
```powershell
# Test profile parameter
.\roboto.ps1 -Profile ultra

# Test URL parameter (not yet functional)
.\roboto.ps1 -Url "https://youtube.com/watch?v=dQw4w9WgXcQ" -Profile high
```

**Expected Output:**
```
[INFO] Profile parameter accepted (not yet used in Sprint 1)
```

**What to verify:**
- ✅ Parameters are accepted without errors
- ✅ Invalid profiles are rejected (e.g., `-Profile invalid`)

---

## Test 10: Clean Reinstall

**What it tests:** Complete reset and reinstall

**Command:**
```powershell
# Delete everything except the script
Remove-Item q:/mr.roboto/bin -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item q:/mr.roboto/logs -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item q:/mr.roboto/config.json -Force -ErrorAction SilentlyContinue
Remove-Item q:/mr.roboto/downloads -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item q:/mr.roboto/cache -Recurse -Force -ErrorAction SilentlyContinue

# Run script
.\roboto.ps1
```

**Expected:** Full initialization as if first run

**What to verify:**
- ✅ All directories recreated
- ✅ Config regenerated
- ✅ Binaries downloaded
- ✅ No errors or warnings

---

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Basic Initialization | ✅ PASSED | All directories created, logging works |
| 2. Dependency Download | ⏳ PENDING | Requires internet connection |
| 3. Offline Mode | ⏳ PENDING | Needs binaries present first |
| 4. Configuration | ✅ PASSED | Valid JSON structure |
| 5. Logging System | ✅ PASSED | Files created correctly |
| 6. GPU Detection | ✅ PASSED | Intel UHD detected, QSV selected |
| 7. Binary Versions | ⏳ PENDING | Binaries not yet downloaded |
| 8. Error Handling | ⏳ PENDING | Needs testing |
| 9. Parameters | ✅ PASSED | Accepted without errors |
| 10. Clean Reinstall | ⏳ PENDING | Needs testing |

---

## Quick Test Script

Run all basic tests automatically:

```powershell
# Save as test-roboto.ps1
Write-Host "=== Mr. Roboto Test Suite ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic run
Write-Host "Test 1: Basic Initialization..." -ForegroundColor Yellow
.\roboto.ps1
Write-Host ""

# Test 2: Check files created
Write-Host "Test 2: Verify Files..." -ForegroundColor Yellow
$files = @(
    "config.json",
    "bin",
    "downloads",
    "logs",
    "state",
    "cache"
)
foreach ($file in $files) {
    $exists = Test-Path "q:/mr.roboto/$file"
    $status = if ($exists) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "  $file : $status"
}
Write-Host ""

# Test 3: Check log content
Write-Host "Test 3: Log Content..." -ForegroundColor Yellow
$logFile = Get-ChildItem q:/mr.roboto/logs/ | Select-Object -Last 1
if ($logFile) {
    Write-Host "  Latest log: $($logFile.Name)" -ForegroundColor Green
    Get-Content $logFile.FullName | Select-Object -Last 5
} else {
    Write-Host "  ❌ No log files found" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Tests Complete ===" -ForegroundColor Cyan
```

---

## Next Steps After Testing

Once all tests pass:

1. **Test dependency downloads** (requires internet)
2. **Implement Sprint 3** (Interactive Menu)
3. **Test actual media downloads** (requires yt-dlp + FFmpeg)
4. **Implement progress tracking**
5. **Test resume capability**

---

## Troubleshooting

### Issue: "Execution Policy" Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Binaries Won't Download
- Check internet connection
- Check firewall settings
- Try manual download from GitHub
- Use `-OfflineMode` with pre-downloaded binaries

### Issue: GPU Not Detected
- Update GPU drivers
- Check Device Manager
- Script will fallback to software encoding

### Issue: Log Files Not Created
- Check write permissions
- Run as administrator
- Check disk space

---

**Current Implementation Status:** Sprint 1 Complete ✅ | Sprint 2 In Progress 🚧

**Ready for:** Dependency download testing and Sprint 3 implementation