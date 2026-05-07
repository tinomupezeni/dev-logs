<#
.SYNOPSIS
    Quick issue logger for dev-logs repository

.DESCRIPTION
    Creates a new issue log from template and opens it in your default editor.
    Automatically determines project from current directory.

.PARAMETER Project
    Project name (CRM, HBEC, SMEPULSE, etc.). Auto-detected if not specified.

.PARAMETER Title
    Brief description for filename (e.g., "backend-crash-loop")

.PARAMETER Severity
    Issue severity: Critical, High, Medium, or Low

.EXAMPLE
    .\log-issue.ps1 -Title "backend-crash-loop" -Severity Critical
    .\log-issue.ps1 -Project CRM -Title "nginx-not-starting" -Severity High
#>

param(
    [Parameter(Position = 0)]
    [string]$Project = "",

    [Parameter(Position = 1, Mandatory = $true)]
    [string]$Title,

    [Parameter(Position = 2)]
    [ValidateSet("Critical", "High", "Medium", "Low")]
    [string]$Severity = "High"
)

$DEV_LOGS_DIR = "C:\Users\Dell\Documents\projects\dev-logs"
$TEMPLATE = "$DEV_LOGS_DIR\templates\issue-template.md"

# Project mapping
$PROJECT_MAP = @{
    "CRM" = @{ Name = "CRM Professional"; Path = "*\CRM\*" }
    "HBEC" = @{ Name = "HBEC Student"; Path = "*\HBEC\*" }
    "SMEPULSE" = @{ Name = "SMEPulse"; Path = "*\SMEPULSE\*" }
    "Tese" = @{ Name = "Tese Marketplace"; Path = "*\New Tesee\*" }
    "ZCHPC-ERP" = @{ Name = "ZCHPC ERP"; Path = "*\ZCHPC-ERP\*" }
    "Market-Link" = @{ Name = "Market Link"; Path = "*\Market-Link\*" }
}

# Auto-detect project if not specified
if (-not $Project) {
    $currentPath = Get-Location
    foreach ($key in $PROJECT_MAP.Keys) {
        if ($currentPath -like $PROJECT_MAP[$key].Path) {
            $Project = $key
            break
        }
    }

    if (-not $Project) {
        Write-Host "Could not auto-detect project. Please specify with -Project parameter." -ForegroundColor Red
        Write-Host "Available projects: $($PROJECT_MAP.Keys -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

# Validate project
if (-not $PROJECT_MAP.ContainsKey($Project)) {
    Write-Host "Unknown project: $Project" -ForegroundColor Red
    Write-Host "Available projects: $($PROJECT_MAP.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Create project folder if it doesn't exist
$projectDir = "$DEV_LOGS_DIR\$Project"
if (-not (Test-Path $projectDir)) {
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Write-Host "Created new project folder: $projectDir" -ForegroundColor Green
}

# Generate filename
$date = Get-Date -Format "yyyy-MM-dd"
$filename = "$date-$($Title.ToLower() -replace '\s+', '-').md"
$logPath = "$projectDir\$filename"

# Check if file already exists
if (Test-Path $logPath) {
    Write-Host "Error: Log file already exists: $logPath" -ForegroundColor Red
    exit 1
}

# Copy template
Copy-Item $TEMPLATE $logPath

# Replace placeholders
$content = Get-Content $logPath -Raw
$content = $content -replace '\[Brief Issue Title\]', ($Title -replace '-', ' ')
$content = $content -replace 'YYYY-MM-DD', $date
$content = $content -replace '\[Project Name\]', $PROJECT_MAP[$Project].Name
$content = $content -replace '\[Critical/High/Medium/Low\]', $Severity
$content = $content -replace '\[Resolved/Investigating/Workaround Applied\]', 'Resolved'
$content = $content -replace '\[Production/Staging/Development\]', 'Production'

Set-Content $logPath $content

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Issue Log Created Successfully" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project:  " -NoNewline
Write-Host $PROJECT_MAP[$Project].Name -ForegroundColor Green
Write-Host "File:     " -NoNewline
Write-Host $logPath -ForegroundColor Yellow
Write-Host "Severity: " -NoNewline
Write-Host $Severity -ForegroundColor $(if ($Severity -eq "Critical") { "Red" } else { "Yellow" })
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit the file and fill in all sections"
Write-Host "  2. Commit: git add $Project\$filename"
Write-Host "  3. Push:   git commit -m '$Project`: Document $Title'"
Write-Host ""

# Open in default editor
Start-Process $logPath

# Return to dev-logs directory
Set-Location $DEV_LOGS_DIR
