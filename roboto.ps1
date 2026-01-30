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

.PARAMETER OfflineMode
    Skip dependency updates and work offline

.EXAMPLE
    .\roboto.ps1
    Interactive mode with menu

.EXAMPLE
    .\roboto.ps1 -Url "https://youtube.com/watch?v=..." -Profile high
    Direct download mode

.NOTES
    Version: 2.0.0
    Author: Mr. Roboto Team
    License: MIT
    
    Requires:
    - Windows 10/11 (x86 or x64)
    - PowerShell 5.1 or later
    - Internet connection (for first run and downloads)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Url,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('ultra', 'high', 'mobile')]
    [string]$Profile = 'high',
    
    [Parameter(Mandatory=$false)]
    [switch]$OfflineMode
)

# Force TLS 1.2+ for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Script-level variables
$script:Version = "2.0.0"
$script:ScriptRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ScriptRoot "config.json"
$script:LogPath = Join-Path $ScriptRoot "logs"
$script:LogFile = $null
$script:Config = $null
$script:Hardware = $null

#region Initialization Functions

function Initialize-Environment {
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
        }
    }
    
    if (-not (Test-Path $script:ConfigPath)) {
        Initialize-Config
    }
    
    try {
        $script:Config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "Error loading configuration: $_" -ForegroundColor Red
        throw
    }
    
    Initialize-Logging
    Write-Log "INFO" "Environment initialized successfully"
}

function Initialize-Config {
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
                description = "4K MKV (best quality)"
            }
            high = @{
                format = "bestvideo[height<=1080]+bestaudio/best"
                container = "mp4"
                videoCodec = "auto"
                audioCodec = "aac"
                description = "1080p MP4 (recommended)"
            }
            mobile = @{
                format = "bestvideo[height<=720]+bestaudio/best"
                container = "mp4"
                videoCodec = "h264"
                audioCodec = "aac"
                description = "720p MP4 (smaller size)"
            }
        }
        binaries = @{
            'yt-dlp' = @{
                x64 = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
                x86 = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_x86.exe"
            }
            'ffmpeg' = @{
                x64 = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
                x86 = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win32-gpl.zip"
            }
        }
    }
    
    try {
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigPath -Encoding UTF8
        Write-Host "Created default configuration file" -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating configuration: $_" -ForegroundColor Red
        throw
    }
}

function Initialize-Logging {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = Join-Path $script:LogPath "session_$timestamp.log"
    
    $cutoffDate = (Get-Date).AddDays(-30)
    Get-ChildItem $script:LogPath -Filter "session_*.log" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Log "INFO" "=== Mr. Roboto v$($script:Version) ==="
    Write-Log "INFO" "Session started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "INFO" "PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Log "INFO" "Operating System: $([Environment]::OSVersion.VersionString)"
}

#endregion

#region Logging & Error Handling

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:LogFile) {
        try { Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction Stop } catch {}
    }

    $color = switch ($Level) {
        'DEBUG' { 'Gray' }
        'INFO'  { 'White' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Handle-Error {
    param(
        [string]$Message = "An unexpected error occurred.",
        [System.Exception]$Exception
    )

    Write-Log "ERROR" $Message
    if ($Exception) {
        Write-Log "ERROR" ("Exception: " + $Exception.Message)
        Write-Log "DEBUG" ("StackTrace: " + $Exception.StackTrace)
    }

    Write-Host ""
    Write-Host $Message -ForegroundColor Red
    if ($Exception) {
        Write-Host ("Details: " + $Exception.Message) -ForegroundColor Yellow
    }

    exit 1
}

#endregion

#region Hardware Detection

function Get-HardwareCapabilities {
    Write-Log "INFO" "Detecting hardware capabilities..."
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    Write-Log "DEBUG" "Architecture: $arch"
    
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | 
               Where-Object { $_.Name -notlike "*Microsoft*" -and $_.Name -notlike "*Remote*" } |
               Select-Object -First 1
        
        if ($gpu) {
            $gpuName = $gpu.Name
            Write-Log "INFO" "GPU detected: $gpuName"
            $encoder = if ($gpuName -match "NVIDIA|GeForce|GTX|RTX|Quadro") { "h264_nvenc" }
                       elseif ($gpuName -match "Intel|HD Graphics|UHD Graphics|Iris") { "h264_qsv" }
                       elseif ($gpuName -match "AMD|Radeon|RX") { "h264_amf" }
                       else { "libx264" }
            Write-Log "INFO" "Selected encoder: $encoder"
        } else {
            $gpuName = "None (Software)"
            $encoder = "libx264"
            Write-Log "WARN" "No dedicated GPU detected, using software encoding"
        }
    }
    catch {
        $gpuName = "Detection Failed"
        $encoder = "libx264"
        Write-Log "WARN" "GPU detection failed: $($_.Exception.Message)"
    }
    
    return @{ GPU = $gpuName; Encoder = $encoder; Architecture = $arch }
}

#endregion

#region Main Entry Point

function Main {
    try {
        Initialize-Environment
        # Dependencies and updates omitted here for brevity
        $script:Hardware = Get-HardwareCapabilities
        Write-Host "Initialization complete. Ready to acquire media." -ForegroundColor Green
    }
    catch {
        Handle-Error -Message "Fatal error occurred during initialization" -Exception $_.Exception
    }
}

Main

#endregion
