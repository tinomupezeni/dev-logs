# ==========================================
# Deployment Verification Script
# ==========================================
#
# This script verifies common deployment issues before they reach production.
# Run this BEFORE and AFTER deployment to catch configuration errors.
#
# Usage:
#   .\verify-deployment.ps1 -ConfigFile .\deployment-config.json
#
# Or for individual checks:
#   .\verify-deployment.ps1 -CheckDomains -CheckAPIURLs -CheckNginx
# ==========================================

param(
    [string]$ConfigFile,
    [string]$VPSUser,
    [string]$VPSHost,
    [string]$ProjectDir,
    [switch]$CheckDomains,
    [switch]$CheckAPIURLs,
    [switch]$CheckNginx,
    [switch]$CheckImages,
    [switch]$CheckAll,
    [switch]$PreDeployment,
    [switch]$PostDeployment
)

$ErrorActionPreference = "Continue"
$FailedChecks = @()
$PassedChecks = @()

# Colors
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Failure { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }

# Load config if provided
if ($ConfigFile) {
    Write-Info "Loading configuration from $ConfigFile"
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    $VPSUser = $Config.vps.user
    $VPSHost = $Config.vps.host
    $ProjectDir = $Config.vps.projectDir
    $Domains = $Config.domains
    $Frontends = $Config.frontends
}

# Set check flags
if ($CheckAll -or $PreDeployment -or $PostDeployment) {
    $CheckDomains = $true
    $CheckAPIURLs = $true
    $CheckNginx = $true
    $CheckImages = $true
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Deployment Verification Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ==========================================
# CHECK 1: Docker Images Have Correct Registry Prefix
# ==========================================
if ($CheckImages -and $PreDeployment) {
    Write-Info "CHECK 1: Verifying Docker image registry prefixes..."

    $ComposeFile = Get-Content "docker-compose.vps.yml" -Raw

    # Extract expected registry prefix from compose file
    if ($ComposeFile -match 'image:\s+([^/]+)/') {
        $ExpectedPrefix = $Matches[1]
        Write-Info "Expected registry prefix: $ExpectedPrefix"

        # Check local deployment script
        $DeployScript = Get-Content "local-deploy.ps1" -Raw
        if ($DeployScript -match '\$REGISTRY_PREFIX\s*=\s*"([^"]+)"') {
            $ActualPrefix = $Matches[1]

            if ($ActualPrefix -eq $ExpectedPrefix) {
                Write-Success "Registry prefix matches: $ActualPrefix"
                $PassedChecks += "Image Registry Prefix"
            } else {
                Write-Failure "Registry prefix mismatch!"
                Write-Failure "  Expected: $ExpectedPrefix (from docker-compose.vps.yml)"
                Write-Failure "  Actual: $ActualPrefix (from local-deploy.ps1)"
                $FailedChecks += "Image Registry Prefix"
            }
        }
    }
}

# ==========================================
# CHECK 2: Vite Build Arguments in Dockerfiles
# ==========================================
if ($CheckAPIURLs -and $PreDeployment) {
    Write-Info "`nCHECK 2: Verifying Dockerfile build arguments..."

    $ViteFrontends = Get-ChildItem -Path "apps" -Directory | Where-Object {
        Test-Path "$($_.FullName)/vite.config.*"
    }

    foreach ($Frontend in $ViteFrontends) {
        $DockerfilePath = "$($Frontend.FullName)/Dockerfile"

        if (Test-Path $DockerfilePath) {
            $Dockerfile = Get-Content $DockerfilePath -Raw

            # Check if Dockerfile has ARG declarations
            if ($Dockerfile -match 'ARG VITE_API_URL') {
                Write-Success "$($Frontend.Name): Has VITE_API_URL build argument"

                # Check if ENV is set from ARG
                if ($Dockerfile -match 'ENV VITE_API_URL=\$VITE_API_URL') {
                    Write-Success "$($Frontend.Name): ENV properly set from ARG"
                    $PassedChecks += "Dockerfile: $($Frontend.Name)"
                } else {
                    Write-Failure "$($Frontend.Name): Missing ENV declaration"
                    $FailedChecks += "Dockerfile: $($Frontend.Name)"
                }
            } else {
                Write-Failure "$($Frontend.Name): Missing VITE_API_URL ARG declaration"
                Write-Warning "  Add: ARG VITE_API_URL=http://localhost:8000/api"
                Write-Warning "  Add: ENV VITE_API_URL=\$VITE_API_URL"
                $FailedChecks += "Dockerfile: $($Frontend.Name)"
            }
        }
    }
}

# ==========================================
# CHECK 3: Build Arguments in Deployment Script
# ==========================================
if ($CheckAPIURLs -and $PreDeployment) {
    Write-Info "`nCHECK 3: Verifying deployment script passes build arguments..."

    $DeployScript = Get-Content "local-deploy.ps1" -Raw

    if ($DeployScript -match '--build-arg VITE_API_URL') {
        Write-Success "Deployment script passes VITE_API_URL build argument"

        # Extract the actual values
        if ($DeployScript -match '--build-arg VITE_API_URL=([^\s`]+)') {
            $ProductionAPIURL = $Matches[1]
            Write-Info "  Production API URL: $ProductionAPIURL"

            # Verify it's not localhost
            if ($ProductionAPIURL -like "*localhost*") {
                Write-Failure "Production API URL contains 'localhost'!"
                $FailedChecks += "Build Args: API URL"
            } else {
                Write-Success "Production API URL is not localhost"
                $PassedChecks += "Build Args: API URL"
            }
        }
    } else {
        Write-Failure "Deployment script does NOT pass VITE_API_URL build argument"
        Write-Warning "  Frontend will use localhost URLs in production!"
        $FailedChecks += "Build Args: Missing"
    }
}

# ==========================================
# CHECK 4: Nginx Configuration (Post-Deployment)
# ==========================================
if ($CheckNginx -and $PostDeployment -and $VPSHost) {
    Write-Info "`nCHECK 4: Verifying nginx configuration on VPS..."

    # Test nginx config syntax
    $NginxTest = ssh "$VPSUser@$VPSHost" "docker exec tese-api-gateway nginx -t 2>&1"

    if ($NginxTest -like "*test is successful*") {
        Write-Success "Nginx configuration syntax is valid"
        $PassedChecks += "Nginx Config Syntax"
    } else {
        Write-Failure "Nginx configuration has syntax errors"
        Write-Host $NginxTest
        $FailedChecks += "Nginx Config Syntax"
    }

    # Verify nginx is running
    $NginxStatus = ssh "$VPSUser@$VPSHost" "docker exec tese-api-gateway ps aux | grep nginx | grep -v grep"

    if ($NginxStatus) {
        Write-Success "Nginx is running"
        $PassedChecks += "Nginx Process"
    } else {
        Write-Failure "Nginx is not running"
        $FailedChecks += "Nginx Process"
    }
}

# ==========================================
# CHECK 5: Domain Routing (Post-Deployment)
# ==========================================
if ($CheckDomains -and $PostDeployment -and $VPSHost) {
    Write-Info "`nCHECK 5: Verifying domain routing..."

    if ($Domains) {
        foreach ($Domain in $Domains) {
            $ExpectedTitle = $Domain.expectedTitle
            $URL = $Domain.url

            $ActualTitle = ssh "$VPSUser@$VPSHost" "curl -s '$URL' | grep -o '<title>[^<]*</title>'"

            if ($ActualTitle -like "*$ExpectedTitle*") {
                Write-Success "$URL → $ActualTitle ✓"
                $PassedChecks += "Domain: $URL"
            } else {
                Write-Failure "$URL → $ActualTitle (Expected: $ExpectedTitle)"
                $FailedChecks += "Domain: $URL"
            }
        }
    } else {
        Write-Warning "No domains configured for verification"
    }
}

# ==========================================
# CHECK 6: API URLs in Built Bundles (Post-Deployment)
# ==========================================
if ($CheckAPIURLs -and $PostDeployment -and $VPSHost) {
    Write-Info "`nCHECK 6: Verifying API URLs in production bundles..."

    if ($Frontends) {
        foreach ($Frontend in $Frontends) {
            $Container = $Frontend.container
            $ExpectedAPI = $Frontend.expectedAPI

            $LocalhostCheck = ssh "$VPSUser@$VPSHost" "docker exec $Container sh -c 'cat /usr/share/nginx/html/assets/index-*.js 2>/dev/null | grep -o \"localhost:8000\" | head -1'"

            if ($LocalhostCheck) {
                Write-Failure "$Container: Contains 'localhost:8000' in bundle!"
                Write-Warning "  Frontend will fail to connect in production"
                $FailedChecks += "API URL: $Container"
            } else {
                Write-Success "$Container: No localhost URLs found"

                # Verify production URL is present
                $ProdURLCheck = ssh "$VPSUser@$VPSHost" "docker exec $Container sh -c 'cat /usr/share/nginx/html/assets/index-*.js 2>/dev/null | grep -o \"$ExpectedAPI\" | head -1'"

                if ($ProdURLCheck) {
                    Write-Success "$Container: Production API URL found ($ExpectedAPI)"
                    $PassedChecks += "API URL: $Container"
                } else {
                    Write-Warning "$Container: Production API URL not found"
                    $FailedChecks += "API URL: $Container"
                }
            }
        }
    }
}

# ==========================================
# SUMMARY
# ==========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Passed: $($PassedChecks.Count)" -ForegroundColor Green
foreach ($check in $PassedChecks) {
    Write-Host "  ✓ $check" -ForegroundColor Green
}

if ($FailedChecks.Count -gt 0) {
    Write-Host "`nFailed: $($FailedChecks.Count)" -ForegroundColor Red
    foreach ($check in $FailedChecks) {
        Write-Host "  ✗ $check" -ForegroundColor Red
    }

    Write-Host "`n⚠ WARNING: Deployment verification failed!" -ForegroundColor Red
    Write-Host "Fix the issues above before deploying to production.`n" -ForegroundColor Yellow

    exit 1
} else {
    Write-Host "`n✓ All checks passed!" -ForegroundColor Green
    if ($PreDeployment) {
        Write-Host "Safe to proceed with deployment.`n" -ForegroundColor Green
    }
    exit 0
}
