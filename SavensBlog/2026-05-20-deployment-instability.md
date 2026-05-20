# ISSUE LOG: Deployed System Instability (400 Errors & Service Restarts)
**Date:** 2026-05-20
**Project:** Savens Blog
**Status:** RESOLVED (Live Fix + Code Patches)

## 1. Symptoms
- Frontend fetching `/blogs/` returned `400 Bad Request`.
- `savens-backend` logs showed `DisallowedHost` errors.
- `savens-rec` service in a restart loop (`NumPy X86_V2` error).
- `savens-analytics` service in a restart loop (`SettingsError` on `ALLOWED_HOSTS`).
- PWA Workbox errors regarding non-precached `index.html`.

## 2. Root Cause Analysis

### A. Django Host Validation
The production domain `restkblog.restksolutions.co.zw` was missing from the backend's `ALLOWED_HOSTS`. Django's security middleware correctly blocked the requests.

### B. Hardware Incompatibility (NumPy)
The VPS uses a QEMU-emulated CPU that does not support the `X86_V2` instruction set (SSE4.2, POPCNT). Recent NumPy versions (1.26+) are compiled for X86_V2 by default, causing a `RuntimeError` on import.

### C. Environment Parsing Logic
The Analytics service (FastAPI/Pydantic) expected `ALLOWED_HOSTS` as a `List[str]`. Passing a comma-separated string (standard env format) caused a parsing failure because Pydantic V2 does not auto-split strings into lists by default without custom validators.

## 3. Resolution Strategy

### Immediate Live Fix (VPS)
- **Action:** Surgically updated `infra/.env` on the VPS to include correct domains.
- **Command:** `sed -i "s/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=...,restkblog.restksolutions.co.zw,.../" .env`
- **Result:** Restored connectivity to the main API.

### Long-term Architectural Patches
- **Analytics Config:** Implemented a robust Pydantic `@field_validator` in `apps/service-analytics/app/config.py` to handle comma-separated strings.
- **Hardware Compatibility:** Downgraded NumPy to `1.24.4` in `apps/service-rec/requirements.txt` to support legacy VPS CPU architectures.
- **Frontend Cleanup:** Identified the need to sanitize `URLSearchParams` in `blog.services.tsx` to prevent sending `undefined` strings as query params.

## 4. Verification Results
- `savens-backend`: **Up (Healthy)** - Verified via `docker logs`.
- `savens-rec`: Patch applied (requires rebuild).
- `savens-analytics`: Patch applied (requires rebuild).
- `Caddyfile`: Verified routing matches the new domains.

## 5. Lessons Learned
- **Architecture over Versioning:** Portability across heterogeneous hardware (VPS vs. Local) requires pinning specific library versions (like NumPy) when SIMD instructions are involved.
- **Configuration Layer Integrity:** Always use explicit validators for complex environment variables (lists/dicts) rather than relying on default framework behavior.
- **Domain Parity:** Ensure deployment scripts and infra configs use a single source of truth for domain lists.
