# Mr. Roboto v2.0 - Developer Guide

## Quick Start for Implementation

This guide provides practical implementation details for developers building Mr. Roboto v2.0.

---

## Development Environment Setup

### Prerequisites

```powershell
# Check PowerShell version (need 5.1+)
$PSVersionTable.PSVersion

# Check execution policy
Get-ExecutionPolicy

# If restricted, set to RemoteSigned (run as admin)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Recommended Tools

- **VS Code** with PowerShell extension
- **PSScriptAnalyzer** for linting
- **Pester** for testing (optional)
- **Windows Terminal** for testing UI

---

## Code Structure

### Main Script Template

```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    Mr. Roboto v2.0 - Autonomous Media Acquisition Agent

.DESCRIPTION
    A portable, self-healing PowerShell automation suite for high-fidelity
    media acquisition, transformation, and archival.

.PARAMETER Url
    Media URL to download (optional, can be provided interactively)

.PARAMETER Profile
    Quality profile: ultra, high, or mobile (default: high)

.EXAMPLE
    .\roboto.ps1
    Interactive mode with menu

.EXAMPLE
    .\roboto.ps1 -Url "https://youtube.com/watch?v=..." -Profile high
    Direct download mode

.NOTES
    Version: 2.0.0
    Author: Your Name
    License: MIT
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Url,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('ultra', 'high', 'mobile')]
    [string]$Profile = 'high'
)

# Script-level variables
$script:Version = "2.0.0"
$script:ScriptRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ScriptRoot "config.json"
$script:LogPath = Join-Path $ScriptRoot "logs"

# Main entry point
function Main {
    try {
        Initialize-Environment
        Show-Banner
        
        if ($Url) {
            # Direct mode
            Start-MediaAcquisition -Url $Url -Profile $Profile
        } else {
            # Interactive mode
            Start-InteractiveMode
        }
    }
    catch {
        Write-Log "ERROR" "Fatal error: $_"
        Write-Host "An error occurred. Check logs for details." -ForegroundColor Red
        exit 1
    }
}

# Call main
Main
```

---

## Module Implementation Guide

### 1. Environment Initialization

```powershell
function Initialize-Environment {
    <#
    .SYNOPSIS
        Initialize the Mr. Roboto environment
    #>
    
    # Create directory structure
    $directories = @(
        'bin/x64',
        'bin/x86',
        'downloads',
        'metadata',
        'logs',
        'state',
        'cache'
    )
    
    foreach ($dir in $directories) {
        $path = Join-Path $script:ScriptRoot $dir
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Log "INFO" "Created directory: $dir"
        }
    }
    
    # Initialize config if missing
    if (-not (Test-Path $script:ConfigPath)) {
        Initialize-Config
    }
    
    # Load configuration
    $script:Config = Get-Content $script:ConfigPath | ConvertFrom-Json
    
    # Initialize logging
    Initialize-Logging
    
    # Check and install dependencies
    Install-Dependencies
}
```

### 2. Configuration Management

```powershell
function Initialize-Config {
    <#
    .SYNOPSIS
        Create default configuration file
    #>
    
    $defaultConfig = @{
        version = "2.0.0"
        settings = @{
            defaultQuality = "high"
            autoUpdate = $true
            offlineMode = $false
            notifications = $true
            preferredContainer = "mp4"
            libraryMode = $false
        }
        profiles = @{
            ultra = @{
                format = "bestvideo[height<=2160]+bestaudio/best"
                container = "mkv"
                videoCodec = "auto"
                audioCodec = "aac"
            }
            high = @{
                format = "bestvideo[height<=1080]+bestaudio/best"
                container = "mp4"
                videoCodec = "auto"
                audioCodec = "aac"
            }
            mobile = @{
                format = "bestvideo[height<=720]+bestaudio/best"
                container = "mp4"
                videoCodec = "h264"
                audioCodec = "aac"
            }
        }
        binaries = @{
            ytdlp = @{
                x64 = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
                x86 = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_x86.exe"
            }
            ffmpeg = @{
                x64 = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
                x86 = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win32-gpl.zip"
            }
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigPath
    Write-Log "INFO" "Created default configuration"
}
```

### 3. Logging System

```powershell
function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system
    #>
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = Join-Path $script:LogPath "session_$timestamp.log"
    
    Write-Log "INFO" "=== Mr. Roboto v$($script:Version) ==="
    Write-Log "INFO" "Session started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

function Write-Log {
    <#
    .SYNOPSIS
        Write log entry
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $script:LogFile -Value $logEntry
    
    # Write to console with color
    $color = switch ($Level) {
        'DEBUG' { 'Gray' }
        'INFO'  { 'White' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
    }
    
    Write-Host $logEntry -ForegroundColor $color
}
```

### 4. GPU Detection

```powershell
function Get-HardwareCapabilities {
    <#
    .SYNOPSIS
        Detect GPU and determine optimal encoder
    #>
    
    Write-Log "INFO" "Detecting hardware capabilities..."
    
    # Detect architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    
    # Query GPU
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | 
               Where-Object { $_.Name -notlike "*Microsoft*" } |
               Select-Object -First 1
        
        if ($gpu) {
            $gpuName = $gpu.Name
            Write-Log "INFO" "GPU detected: $gpuName"
            
            # Determine encoder
            $encoder = if ($gpuName -match "NVIDIA") {
                "h264_nvenc"
            } elseif ($gpuName -match "Intel") {
                "h264_qsv"
            } elseif ($gpuName -match "AMD|Radeon") {
                "h264_amf"
            } else {
                "libx264"
            }
            
            Write-Log "INFO" "Selected encoder: $encoder"
        } else {
            $gpuName = "None (Software)"
            $encoder = "libx264"
            Write-Log "WARN" "No GPU detected, using software encoding"
        }
    }
    catch {
        $gpuName = "Detection Failed"
        $encoder = "libx264"
        Write-Log "WARN" "GPU detection failed: $_"
    }
    
    return @{
        GPU = $gpuName
        Encoder = $encoder
        Architecture = $arch
    }
}
```

### 5. Binary Management

```powershell
function Find-Binary {
    <#
    .SYNOPSIS
        Locate binary in local bin or PATH
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $localPath = Join-Path $script:ScriptRoot "bin/$arch/$Name.exe"
    
    # Check local bin
    if (Test-Path $localPath) {
        Write-Log "DEBUG" "Found $Name in local bin"
        return $localPath
    }
    
    # Check PATH
    $pathBinary = Get-Command $Name -ErrorAction SilentlyContinue
    if ($pathBinary) {
        Write-Log "DEBUG" "Found $Name in PATH: $($pathBinary.Source)"
        return $pathBinary.Source
    }
    
    Write-Log "DEBUG" "$Name not found"
    return $null
}

function Install-Dependencies {
    <#
    .SYNOPSIS
        Download and install missing dependencies
    #>
    
    Write-Log "INFO" "Checking dependencies..."
    
    $ytdlpPath = Find-Binary "yt-dlp"
    $ffmpegPath = Find-Binary "ffmpeg"
    
    if (-not $ytdlpPath) {
        Write-Log "INFO" "Downloading yt-dlp..."
        Install-Binary "yt-dlp"
    }
    
    if (-not $ffmpegPath) {
        Write-Log "INFO" "Downloading FFmpeg..."
        Install-Binary "ffmpeg"
    }
    
    Write-Log "INFO" "All dependencies ready"
}

function Install-Binary {
    <#
    .SYNOPSIS
        Download and install a binary
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('yt-dlp', 'ffmpeg')]
        [string]$Name
    )
    
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $binDir = Join-Path $script:ScriptRoot "bin/$arch"
    $url = $script:Config.binaries.$Name.$arch
    
    try {
        if ($Name -eq 'yt-dlp') {
            # Direct download
            $outputPath = Join-Path $binDir "yt-dlp.exe"
            Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
            Write-Log "INFO" "yt-dlp installed successfully"
        }
        elseif ($Name -eq 'ffmpeg') {
            # Download and extract zip
            $zipPath = Join-Path $script:ScriptRoot "cache/ffmpeg.zip"
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            
            # Extract (FFmpeg is in nested folder)
            Expand-Archive -Path $zipPath -DestinationPath (Join-Path $script:ScriptRoot "cache") -Force
            
            # Find and copy binaries
            $extractedDir = Get-ChildItem (Join-Path $script:ScriptRoot "cache") -Directory | 
                           Where-Object { $_.Name -like "ffmpeg-*" } | 
                           Select-Object -First 1
            
            Copy-Item (Join-Path $extractedDir.FullName "bin/ffmpeg.exe") $binDir -Force
            Copy-Item (Join-Path $extractedDir.FullName "bin/ffprobe.exe") $binDir -Force
            
            # Cleanup
            Remove-Item $zipPath -Force
            Remove-Item $extractedDir.FullName -Recurse -Force
            
            Write-Log "INFO" "FFmpeg installed successfully"
        }
    }
    catch {
        Write-Log "ERROR" "Failed to install $Name: $_"
        throw
    }
}
```

### 6. Interactive Menu

```powershell
function Start-InteractiveMode {
    <#
    .SYNOPSIS
        Run interactive menu system
    #>
    
    while ($true) {
        Write-Host "`nSelect Quality Profile:" -ForegroundColor Cyan
        Write-Host "  [1] Ultra  - 4K MKV (best quality)" -ForegroundColor White
        Write-Host "  [2] High   - 1080p MP4 (recommended)" -ForegroundColor Green
        Write-Host "  [3] Mobile - 720p MP4 (smaller size)" -ForegroundColor Yellow
        Write-Host "  [Q] Quit" -ForegroundColor Red
        Write-Host ""
        
        $choice = Read-Host "Choice"
        
        $profile = switch ($choice.ToUpper()) {
            '1' { 'ultra' }
            'U' { 'ultra' }
            '2' { 'high' }
            'H' { 'high' }
            '3' { 'mobile' }
            'M' { 'mobile' }
            'Q' { return }
            default { 
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                continue
            }
        }
        
        Write-Host "`nEnter media URL:" -ForegroundColor Cyan
        $url = Read-Host "URL"
        
        if (-not (Test-MediaUrl $url)) {
            Write-Host "Invalid URL. Please try again." -ForegroundColor Red
            continue
        }
        
        Start-MediaAcquisition -Url $url -Profile $profile
        
        Write-Host "`nDownload another? (Y/N)" -ForegroundColor Cyan
        $continue = Read-Host
        if ($continue -ne 'Y' -and $continue -ne 'y') {
            break
        }
    }
}

function Test-MediaUrl {
    <#
    .SYNOPSIS
        Validate media URL
    #>
    param([string]$Url)
    
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }
    
    if ($Url -notmatch '^https?://') {
        return $false
    }
    
    return $true
}
```

### 7. Download Orchestration

```powershell
function Start-MediaAcquisition {
    <#
    .SYNOPSIS
        Orchestrate media download
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$true)]
        [string]$Profile
    )
    
    Write-Log "INFO" "Starting acquisition: $Url (Profile: $Profile)"
    
    # Get paths
    $ytdlpPath = Find-Binary "yt-dlp"
    $ffmpegPath = Find-Binary "ffmpeg"
    $downloadPath = Join-Path $script:ScriptRoot "downloads"
    
    # Get profile settings
    $profileSettings = $script:Config.profiles.$Profile
    
    # Get hardware info
    $hardware = Get-HardwareCapabilities
    
    # Build command
    $ytdlpArgs = @(
        $Url,
        '--format', $profileSettings.format,
        '--output', "$downloadPath/%(title)s.%(ext)s",
        '--merge-output-format', $profileSettings.container,
        '--ffmpeg-location', (Split-Path $ffmpegPath),
        '--progress',
        '--newline'
    )
    
    # Add encoder if hardware acceleration available
    if ($hardware.Encoder -ne 'libx264') {
        $ytdlpArgs += '--postprocessor-args', "ffmpeg:-c:v $($hardware.Encoder)"
    }
    
    # Execute download
    try {
        Write-Host "`nDownloading..." -ForegroundColor Green
        & $ytdlpPath $ytdlpArgs
        
        Write-Log "INFO" "Download completed successfully"
        Write-Host "`nDownload complete!" -ForegroundColor Green
    }
    catch {
        Write-Log "ERROR" "Download failed: $_"
        Write-Host "`nDownload failed. Check logs for details." -ForegroundColor Red
    }
}
```

### 8. Startup Banner

```powershell
function Show-Banner {
    <#
    .SYNOPSIS
        Display startup banner
    #>
    
    $hardware = Get-HardwareCapabilities
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Mr. Roboto v$($script:Version)                          ║" -ForegroundColor Cyan
    Write-Host "║        Autonomous Media Acquisition Agent             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "System Information:" -ForegroundColor Yellow
    Write-Host "  GPU: $($hardware.GPU)" -ForegroundColor White
    Write-Host "  Encoder: $($hardware.Encoder)" -ForegroundColor White
    Write-Host "  Architecture: $($hardware.Architecture)" -ForegroundColor White
    Write-Host "  Mode: Interactive" -ForegroundColor White
    Write-Host ""
    Write-Host "Ready to acquire media." -ForegroundColor Green
    Write-Host ""
}
```

---

## Testing Checklist

### Manual Testing

- [ ] First run (no binaries)
- [ ] Subsequent runs (binaries present)
- [ ] GPU detection (NVIDIA/Intel/AMD/None)
- [ ] Each quality profile (ultra/high/mobile)
- [ ] Valid URL download
- [ ] Invalid URL handling
- [ ] Network failure recovery
- [ ] Disk space check
- [ ] Log file creation
- [ ] Config file creation

### Test URLs

```powershell
# Short video for quick testing
$testUrl = "https://www.youtube.com/watch?v=jNQXAC9IVRw"  # "Me at the zoo" (18s)

# Test command
.\roboto.ps1 -Url $testUrl -Profile mobile
```

---

## Common Issues & Solutions

### Issue: Execution Policy Restricted

```powershell
# Solution: Set execution policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Binary Download Fails

```powershell
# Solution: Check network and retry
# Or manually download and place in bin/x64/
```

### Issue: GPU Not Detected

```powershell
# Solution: Update GPU drivers or use software encoding
# Encoder will automatically fallback to libx264
```

### Issue: FFmpeg Extraction Fails

```powershell
# Solution: Manually extract and copy to bin/x64/
# Or use 7-Zip if Expand-Archive fails
```

---

## Performance Tips

1. **Use SSD** for downloads folder
2. **Close other apps** during encoding
3. **Update GPU drivers** for best performance
4. **Use wired connection** for stability
5. **Monitor disk space** before large downloads

---

## Next Steps

1. Implement core functions in order
2. Test each module independently
3. Integrate modules progressively
4. Perform end-to-end testing
5. Refine based on real-world usage

---

## Resources

- [yt-dlp Documentation](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)

---

**Ready to build? Switch to Code mode and let's implement!**