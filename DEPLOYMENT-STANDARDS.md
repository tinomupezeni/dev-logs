# Deployment Standards & Best Practices

This document establishes standards to prevent common deployment issues across all projects.

## Table of Contents
- [Overview](#overview)
- [Critical Rules](#critical-rules)
- [Vite Frontend Deployments](#vite-frontend-deployments)
- [Nginx Configuration](#nginx-configuration)
- [Docker Image Management](#docker-image-management)
- [Verification Process](#verification-process)
- [Templates & Tools](#templates--tools)
- [Project Onboarding Checklist](#project-onboarding-checklist)

---

## Overview

**Last Updated:** 2026-05-15
**Applies To:** All production deployments

This document was created after resolving critical production issues in the Tese Marketplace project where:
1. Nginx configuration wasn't reloaded, causing domain routing to be swapped
2. Vite frontends were hardcoded to localhost instead of production API URLs

**These errors must NEVER occur again in any project.**

---

## Critical Rules

### ❌ NEVER Do These

1. **Never rely on runtime environment variables for Vite apps**
   - Vite embeds `import.meta.env.VITE_*` at BUILD TIME
   - Docker runtime env vars in `docker-compose.yml` won't work

2. **Never deploy without verifying the build output**
   - Always check that localhost URLs aren't in production bundles
   - Always verify correct API URLs are embedded

3. **Never skip nginx configuration reload after updates**
   - Config files can be updated but not loaded in memory
   - Always run `nginx -s reload` after config changes

4. **Never have registry prefix mismatches**
   - Deployment script prefix must match docker-compose image prefix
   - Use a single source of truth (config file)

5. **Never deploy without testing domain routing**
   - Verify each domain serves the correct application
   - Test with actual HTTP requests, not just assumptions

6. **Never use ambiguous identifiers for Foreign Keys**
   - In distributed systems (like Shipwright), use UUIDs for relationships
   - Human-readable names are for display/logging ONLY

7. **Never use unescaped complex commands in SSH/PowerShell**
   - PowerShell interpretation of backslashes can break remote execution
   - Always use simple quoting or Here-Strings for remote scripts

### ✅ ALWAYS Do These

1. **Always use build arguments for Vite environment variables**
   ```dockerfile
   ARG VITE_API_URL=http://localhost:8000/api
   ENV VITE_API_URL=$VITE_API_URL
   ```

2. **Always verify builds before deployment**
   ```bash
   # Check for localhost in production builds
   grep -r "localhost:8000" dist/ && exit 1 || echo "OK"
   ```

3. **Always reload nginx after configuration updates**
   ```bash
   docker exec nginx-container nginx -s reload
   ```

4. **Always use configuration files for deployment settings**
   - Avoid hardcoding values in multiple places
   - Use JSON/YAML config files as single source of truth

5. **Always run pre-deployment verification**
   ```powershell
   .\verify-deployment.ps1 -PreDeployment -ConfigFile deployment-config.json
   ```

6. **Always run post-deployment verification**
   ```powershell
   .\verify-deployment.ps1 -PostDeployment -ConfigFile deployment-config.json
   ```

---

## Vite Frontend Deployments

### The Problem

Vite (and most build tools) perform **static replacement** of environment variables during the build process. When you write:

```typescript
const API_URL = import.meta.env.VITE_API_URL;
```

Vite replaces this with the **actual value** at build time:

```typescript
const API_URL = "https://api.myapp.com";  // Static value, embedded in bundle
```

This means:
- ❌ Setting `VITE_API_URL` in `docker-compose.yml` doesn't work (too late)
- ❌ Setting `VITE_API_URL` in container environment doesn't work (too late)
- ✅ Setting `VITE_API_URL` during Docker build DOES work (just in time)

### The Solution

**Use Docker Build Arguments:**

#### 1. Update Dockerfile

Use the standard template: `templates/Dockerfile.vite-frontend`

Key sections:
```dockerfile
# Define build arguments with development defaults
ARG VITE_API_URL=http://localhost:8000/api
ARG VITE_WS_URL=localhost:8000

# Convert to environment variables for Vite
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_WS_URL=$VITE_WS_URL

# Build the application (Vite now sees production values)
RUN npm run build

# OPTIONAL: Verify no localhost in production build
RUN grep -r "localhost:8000" dist/ && exit 1 || echo "Build OK"
```

#### 2. Update Deployment Script

Pass build arguments during `docker build`:

```powershell
docker build -t myapp:latest `
  --build-arg VITE_API_URL=https://api.myapp.com `
  --build-arg VITE_WS_URL=wss://api.myapp.com `
  .
```

#### 3. Load from Configuration File

**Best Practice:** Don't hardcode URLs in deployment script.

```powershell
$Config = Get-Content "deployment-config.json" | ConvertFrom-Json
$BuildArgs = $Config.frontends | Where-Object { $_.name -eq $AppName } | Select-Object -First 1

$BuildArgString = ""
foreach ($key in $BuildArgs.buildArgs.PSObject.Properties.Name) {
    $value = $BuildArgs.buildArgs.$key
    $BuildArgString += "--build-arg ${key}=${value} "
}

docker build -t $ImageName $BuildArgString .
```

### Verification

After building, verify the bundle:

```bash
# Should find production URL
grep -o "https://api.myapp.com" dist/assets/*.js

# Should NOT find localhost
grep "localhost:8000" dist/assets/*.js && echo "ERROR: localhost found!" || echo "OK"
```

After deployment, verify on VPS:

```bash
ssh user@host "docker exec frontend-container sh -c 'cat /usr/share/nginx/html/assets/*.js | grep -o \"localhost:8000\"'"
# Should return nothing (exit 1)

ssh user@host "docker exec frontend-container sh -c 'cat /usr/share/nginx/html/assets/*.js | grep -o \"https://api.myapp.com\"'"
# Should return the production URL
```

---

## Nginx Configuration

### The Problem

Nginx can have correct configuration files on disk but still use old configurations in memory. This happens when:
- Configuration files are updated but nginx isn't reloaded
- Containers are restarted but config wasn't changed (no reload triggered)
- Nginx is running with stale routing rules

### The Solution

#### 1. Always Test Configuration

Before reloading:
```bash
docker exec nginx-container nginx -t
```

Output should be:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### 2. Always Reload After Updates

After updating nginx.conf:
```bash
# Copy new config
scp nginx.conf user@host:/path/to/project/nginx/nginx.conf

# Reload nginx
ssh user@host "docker exec nginx-container nginx -s reload"
```

#### 3. Verify Routing

Test with Host headers:
```bash
# Should route to correct upstream
docker exec nginx-container curl -H 'Host: myapp.com' localhost | grep '<title>'
docker exec nginx-container curl -H 'Host: admin.myapp.com' localhost | grep '<title>'
```

#### 4. Test Live Domains

```bash
curl -s https://myapp.com | grep '<title>'
curl -s https://admin.myapp.com | grep '<title>'
```

### Standard Nginx Configuration Template

Use virtual hosts with server_name matching:

```nginx
upstream customer_frontend {
    server customer-app:80;
}

upstream admin_frontend {
    server admin-app:80;
}

# Customer site
server {
    listen 80;
    server_name myapp.com www.myapp.com;

    location / {
        proxy_pass http://customer_frontend;
        proxy_set_header Host $host;
        # ... other headers
    }
}

# Admin site
server {
    listen 80;
    server_name admin.myapp.com;

    location / {
        proxy_pass http://admin_frontend;
        proxy_set_header Host $host;
        # ... other headers
    }
}
```

**Key points:**
- Use explicit `server_name` directives
- Don't rely on default_server for important routes
- Always set `Host` header in proxy_pass

---

## Docker Image Management

### The Problem

Registry prefix mismatches cause confusion:
- Building: `docker build -t userA/myapp:latest`
- Deploying: `docker-compose.yml` references `userB/myapp:latest`
- Result: Old images get deployed, new images ignored

### The Solution

#### 1. Single Source of Truth

Use a configuration file:

```json
{
  "registry": {
    "prefix": "myusername"
  }
}
```

#### 2. Load in All Scripts

**Build script:**
```powershell
$Config = Get-Content "deployment-config.json" | ConvertFrom-Json
$REGISTRY_PREFIX = $Config.registry.prefix
$IMAGE_NAME = "${REGISTRY_PREFIX}/myapp:latest"
```

**docker-compose.yml:**
```yaml
services:
  myapp:
    image: ${REGISTRY_PREFIX:-myusername}/myapp:latest
```

**Deployment script:**
```powershell
$Config = Get-Content "deployment-config.json" | ConvertFrom-Json
$REGISTRY_PREFIX = $Config.registry.prefix
```

#### 3. Verification

Before building:
```powershell
# Extract registry prefix from docker-compose.yml
$ComposePrefix = (Select-String -Path "docker-compose.yml" -Pattern "image:\s+([^/]+)/" | ForEach-Object { $_.Matches.Groups[1].Value }) | Select-Object -First 1

# Extract registry prefix from config
$ConfigPrefix = (Get-Content "deployment-config.json" | ConvertFrom-Json).registry.prefix

if ($ComposePrefix -ne $ConfigPrefix) {
    Write-Error "Registry prefix mismatch: compose=$ComposePrefix, config=$ConfigPrefix"
    exit 1
}
```

---

## Verification Process

### Pre-Deployment Checks

Run **before** building and deploying:

```powershell
.\verify-deployment.ps1 -PreDeployment -ConfigFile deployment-config.json
```

This checks:
1. ✓ Registry prefix matches between compose and deployment script
2. ✓ Dockerfiles have proper ARG/ENV declarations for VITE_* variables
3. ✓ Deployment script passes build arguments
4. ✓ Build arguments don't contain localhost URLs

### Post-Deployment Checks

Run **after** deployment completes:

```powershell
.\verify-deployment.ps1 -PostDeployment -ConfigFile deployment-config.json
```

This checks:
1. ✓ Nginx configuration is valid
2. ✓ Nginx is running
3. ✓ Domains route to correct applications
4. ✓ Frontend bundles contain production API URLs (not localhost)
5. ✓ Health check endpoints respond correctly

### Integration with Deployment Script

Add to your deployment script:

```powershell
# At the start
Write-Host "Running pre-deployment verification..."
.\verify-deployment.ps1 -PreDeployment -ConfigFile deployment-config.json
if ($LASTEXITCODE -ne 0) {
    Write-Error "Pre-deployment checks failed. Aborting."
    exit 1
}

# ... deployment code ...

# At the end
Write-Host "Running post-deployment verification..."
.\verify-deployment.ps1 -PostDeployment -ConfigFile deployment-config.json
if ($LASTEXITCODE -ne 0) {
    Write-Error "Post-deployment checks failed. Rollback may be needed."
    exit 1
}
```

---

## Templates & Tools

All templates are in the `templates/` directory:

### 1. Dockerfile.vite-frontend
Standard Dockerfile for Vite-based frontends with proper build argument handling.

**Usage:**
```bash
cp templates/Dockerfile.vite-frontend apps/my-app/Dockerfile
# Edit to customize package manager, paths, etc.
```

### 2. verify-deployment.ps1
Automated verification script for pre and post deployment checks.

**Usage:**
```powershell
# Pre-deployment
.\verify-deployment.ps1 -PreDeployment -ConfigFile deployment-config.json

# Post-deployment
.\verify-deployment.ps1 -PostDeployment -ConfigFile deployment-config.json

# Individual checks
.\verify-deployment.ps1 -CheckDomains -CheckAPIURLs -VPSHost 159.198.42.231 -VPSUser myuser
```

### 3. deployment-config.example.json
Template for project-specific deployment configuration.

**Usage:**
```bash
cp templates/deployment-config.example.json deployment-config.json
# Edit with your project details
# Add to .gitignore if it contains secrets
```

### 4. pre-commit-hook.sh (TODO)
Git pre-commit hook to catch issues before they reach the repository.

### 5. ci-cd-pipeline.yml (TODO)
GitHub Actions / GitLab CI template with automated verification.

---

## Project Onboarding Checklist

Use this checklist when setting up a new project or auditing an existing one:

### Initial Setup

- [ ] Copy `deployment-config.example.json` to project root as `deployment-config.json`
- [ ] Fill in all project-specific values (VPS host, domains, registry prefix)
- [ ] Copy `verify-deployment.ps1` to project root
- [ ] Add verification script to `.gitignore` or commit it (no secrets in script)

### Frontend Applications

For each Vite/React/Vue frontend:

- [ ] Replace Dockerfile with `Dockerfile.vite-frontend` template
- [ ] Customize Dockerfile for your package manager (npm/pnpm/yarn)
- [ ] Add all `VITE_*` environment variables as ARG declarations
- [ ] Add corresponding ENV declarations
- [ ] Add build verification step (grep check for localhost)
- [ ] Test local build with production URLs
- [ ] Verify bundle doesn't contain localhost

### Deployment Scripts

- [ ] Load `deployment-config.json` at start of script
- [ ] Use config values instead of hardcoded values
- [ ] Pass build arguments from config during `docker build`
- [ ] Add pre-deployment verification call
- [ ] Add post-deployment verification call
- [ ] Add error handling (exit on verification failure)

### Nginx Configuration

- [ ] Use explicit `server_name` directives
- [ ] Set `proxy_set_header Host $host` in all proxy_pass blocks
- [ ] Add reload command to deployment script after config updates
- [ ] Test configuration locally before deploying
- [ ] Add post-deployment routing verification

### Docker Compose

- [ ] Use environment variable for registry prefix: `${REGISTRY_PREFIX:-default}/image:tag`
- [ ] Ensure images have health checks
- [ ] Document which env vars are build-time vs runtime
- [ ] Remove VITE_* from runtime environment (they don't work)

### Documentation

- [ ] Document all environment variables in README
- [ ] Indicate which are build-time (Dockerfile ARG) vs runtime (compose ENV)
- [ ] Document deployment process
- [ ] Document rollback process
- [ ] Document verification process

### Testing

- [ ] Test full deployment to staging environment
- [ ] Run pre-deployment verification
- [ ] Run post-deployment verification
- [ ] Test domain routing manually
- [ ] Test API connectivity from browser
- [ ] Check browser console for errors
- [ ] Verify no localhost URLs in network tab

### Ongoing Maintenance

- [ ] Run verification before every deployment
- [ ] Monitor logs for configuration issues
- [ ] Keep templates updated as patterns evolve
- [ ] Document any new gotchas in dev-logs
- [ ] Review and update this checklist quarterly

---

## Common Pitfalls & Solutions

### Pitfall 1: "I updated .env but production still uses old values"

**Problem:** `.env` files are only used during development. Vite doesn't load them in production.

**Solution:** Use build arguments in Dockerfile, not .env files.

### Pitfall 2: "I set VITE_API_URL in docker-compose.yml but it's ignored"

**Problem:** Vite embeds values at build time, not container runtime.

**Solution:** Pass via `--build-arg` during `docker build`, not in docker-compose.yml.

### Pitfall 3: "Nginx config looks correct but routing is wrong"

**Problem:** Nginx hasn't reloaded the configuration.

**Solution:** Always run `nginx -s reload` after updating config files.

### Pitfall 4: "I tagged the image correctly but old image is deployed"

**Problem:** Registry prefix mismatch or caching issue.

**Solution:**
- Verify registry prefixes match everywhere
- Use `--force-recreate` when deploying
- Check image IDs, not just tags

### Pitfall 5: "localhost works but production URLs fail"

**Problem:** Build-time environment variables weren't set, so Vite used .env defaults.

**Solution:** Always pass production URLs as build arguments, verify bundle before deploying.

### Pitfall 6: "NameError: Depends is not defined"

**Problem:** Copy-pasting code or missing imports in API entry points.

**Solution:** Use `ruff check` locally and include mandatory `Deep Health Check` imports.

### Pitfall 7: "PowerShell remote script execution fails with syntax error"

**Problem:** Broken shell escaping when passing complex strings to SSH.

**Solution:** Use single quotes for the remote command and Here-Strings for PowerShell variables.

---

## Emergency Response

If you discover these issues in production:

### Issue: Frontend connecting to localhost

**Immediate Fix:**
1. SSH into VPS
2. Rebuild frontend with correct build arguments
3. Transfer image to VPS
4. Recreate container: `docker compose up -d --force-recreate frontend`
5. Verify bundle contains production URLs

**Example:**
```bash
# Locally
docker build -t myapp:latest --build-arg VITE_API_URL=https://api.myapp.com .
docker save myapp:latest | ssh user@host "docker load"

# On VPS
ssh user@host "cd /path/to/project && docker compose up -d --force-recreate frontend"
```

### Issue: Domain routing is swapped

**Immediate Fix:**
```bash
ssh user@host "docker exec nginx-container nginx -s reload"
```

**Verify:**
```bash
ssh user@host "curl -s https://myapp.com | grep '<title>'"
```

### Issue: Can't tell what's in production bundle

**Diagnostic:**
```bash
# SSH into VPS
ssh user@host

# Check container file timestamps
docker exec frontend-container ls -la /usr/share/nginx/html/assets/

# Search for API URLs
docker exec frontend-container sh -c 'cat /usr/share/nginx/html/assets/*.js | grep -o "http[s]*://[^\"]*api"' | sort -u

# Search for localhost
docker exec frontend-container sh -c 'cat /usr/share/nginx/html/assets/*.js | grep -o "localhost:[0-9]*"'
```

---

## Changelog

| Date       | Change                                                    |
|------------|-----------------------------------------------------------|
| 2026-05-17 | Added Shell Escaping and Distributed Type Awareness rules  |
| 2026-05-15 | Initial version based on Tese Marketplace incident        |
| 2026-05-15 | Added Vite environment variable standards                 |
| 2026-05-15 | Added verification script and templates                   |

---

## References

- [Tese Marketplace Incident Log](tese-marketplace/2026-05-15-domain-routing-swap-and-frontend-api-connection.md)
- [Vite Environment Variables Docs](https://vitejs.dev/guide/env-and-mode.html)
- [Docker Build Arguments](https://docs.docker.com/engine/reference/builder/#arg)
- [Nginx Reload](https://nginx.org/en/docs/beginners_guide.html#control)

---

**Maintained By:** Winston Mupezeni
**Last Review:** 2026-05-15
**Next Review:** 2026-08-15 (Quarterly)
