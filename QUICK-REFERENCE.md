# Deployment Quick Reference Guide

**For immediate use when deploying projects**

## Before Every Deployment

### 1. Check Registry Prefix
```powershell
# Ensure deployment script matches docker-compose
grep "REGISTRY_PREFIX" local-deploy.ps1
grep "image:" docker-compose.yml | head -1
```

### 2. Verify Vite Build Args
```powershell
# Check Dockerfile has ARG/ENV declarations
grep -E "ARG VITE_|ENV VITE_" apps/*/Dockerfile

# Check deployment script passes build args
grep "build-arg VITE_" local-deploy.ps1
```

### 3. Run Pre-Deployment Verification
```powershell
.\verify-deployment.ps1 -PreDeployment -ConfigFile deployment-config.json
```

## During Deployment

### Build Frontend with Production URLs
```bash
docker build -t myapp:latest \
  --build-arg VITE_API_URL=https://api.myapp.com \
  --build-arg VITE_WS_URL=wss://api.myapp.com \
  .
```

### Verify Build Output Locally
```bash
# Should NOT contain localhost
grep -r "localhost:8000" dist/ && echo "ERROR" || echo "OK"

# Should contain production URL
grep -r "https://api.myapp.com" dist/ && echo "OK" || echo "ERROR"
```

### After Deploying Nginx Config
```bash
# Test config
ssh user@host "docker exec nginx-container nginx -t"

# Reload config
ssh user@host "docker exec nginx-container nginx -s reload"
```

## After Deployment

### 1. Test Domain Routing
```bash
ssh user@host "curl -s https://myapp.com | grep '<title>'"
ssh user@host "curl -s https://admin.myapp.com | grep '<title>'"
```

### 2. Verify API URLs in Production
```bash
# Check for localhost (should be empty)
ssh user@host "docker exec frontend sh -c 'cat /usr/share/nginx/html/assets/*.js | grep localhost:8000'"

# Check for production URL (should appear)
ssh user@host "docker exec frontend sh -c 'cat /usr/share/nginx/html/assets/*.js | grep https://api.myapp.com'"
```

### 3. Run Post-Deployment Verification
```powershell
.\verify-deployment.ps1 -PostDeployment -ConfigFile deployment-config.json
```

## Emergency Fixes

### Frontend Has localhost URLs
```bash
# Rebuild with correct URLs
docker build -t myapp:latest --build-arg VITE_API_URL=https://api.myapp.com .

# Transfer to VPS
docker save myapp:latest | ssh user@host "docker load"

# Recreate container
ssh user@host "cd /path/to/project && docker compose up -d --force-recreate frontend"
```

### Domain Routing is Wrong
```bash
# Reload nginx
ssh user@host "docker exec nginx-container nginx -s reload"

# Verify
ssh user@host "curl -s https://myapp.com | grep '<title>'"
```

### Can't Tell What's Deployed
```bash
# Check file timestamps
ssh user@host "docker exec frontend ls -la /usr/share/nginx/html/assets/"

# Check what API URLs are in bundle
ssh user@host "docker exec frontend sh -c 'cat /usr/share/nginx/html/assets/*.js' | grep -o 'http[s]*://[^\"]*api' | sort -u"
```

## Common Commands

### SSH into VPS
```bash
ssh winstontino@159.198.42.231
```

### Check Container Status
```bash
ssh user@host "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### View Container Logs
```bash
ssh user@host "docker logs -f container-name"
```

### Restart Specific Container
```bash
ssh user@host "cd /path/to/project && docker compose up -d --force-recreate container-name"
```

### Check Nginx Config
```bash
ssh user@host "docker exec nginx-container cat /etc/nginx/conf.d/default.conf"
```

## Checklist

Before deploying:
- [ ] Registry prefix matches everywhere
- [ ] Dockerfiles have ARG/ENV for VITE_* variables
- [ ] Deployment script passes --build-arg for all VITE_* variables
- [ ] Build args contain production URLs (no localhost)
- [ ] Local build verification passed
- [ ] Pre-deployment verification passed

After deploying:
- [ ] All containers are running
- [ ] Nginx configuration reloaded
- [ ] Domain routing is correct
- [ ] Frontend bundles contain production API URLs
- [ ] No localhost URLs in production bundles
- [ ] Post-deployment verification passed
- [ ] Manual smoke test in browser

## Key Files

- `DEPLOYMENT-STANDARDS.md` - Full standards document
- `templates/Dockerfile.vite-frontend` - Standard Dockerfile template
- `templates/verify-deployment.ps1` - Verification script
- `templates/deployment-config.example.json` - Config template
- `local-deploy-enhanced.ps1` - Enhanced deployment script (Tese Marketplace)

## Resources

- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [Docker Build Arguments](https://docs.docker.com/engine/reference/builder/#arg)
- [Nginx Reload](https://nginx.org/en/docs/beginners_guide.html#control)

---

**Last Updated:** 2026-05-15
