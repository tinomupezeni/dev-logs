# CRM Professional - Issue Log

Issues and solutions for the CRM Professional application.

**Project URL:** https://crm.restksolutions.co.zw
**Repository:** C:\Users\Dell\Documents\projects\CRM
**VPS:** winstontino@159.198.42.231

## All Issues

### 2026

#### May
- [2026-05-07 - Backend Crash Loop - Static Files Permission Error](./2026-05-07-backend-crash-loop-static-files-permissions.md) - **Critical** - Resolved

## Statistics

- **Total Issues:** 1
- **Resolved:** 1
- **Open:** 0
- **Average Resolution Time:** 1.5 hours

## Common Issues & Quick Fixes

### Container not starting
```bash
# Check logs
docker compose logs --tail=50 [service_name]

# Check volume permissions
docker run --rm -v crm_static_files:/staticfiles alpine ls -la /staticfiles
```

### Network connectivity issues
```bash
# Verify nginx is on both networks
docker inspect crm-nginx-1 | grep -A 20 'Networks'

# Connect to proxy-tier if missing
docker network connect --alias crm-nginx proxy-tier crm-nginx-1
```

### Site not accessible
```bash
# Test from VPS
curl -I https://crm.restksolutions.co.zw/login

# Check container health
docker compose ps
```

---

**Last Updated:** 2026-05-07
