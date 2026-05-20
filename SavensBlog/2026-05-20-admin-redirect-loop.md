# ISSUE LOG: Admin Dashboard Redirect Loop (ERR_TOO_MANY_REDIRECTS)
**Date:** 2026-05-20
**Project:** Savens Blog
**Status:** RESOLVED (Architectural Proxy Alignment)

## 1. Symptoms
- Accessing `https://blogadmin.hbca.tech/login/` resulted in `net::ERR_TOO_MANY_REDIRECTS`.
- The browser was caught in an infinite loop of 301/308 redirects back to the same URL.

## 2. Root Cause Analysis
The issue was a **Protocol Header Mismatch** in the multi-tier reverse proxy architecture:
1. **Caddy (Layer 1)**: Received the HTTPS request and proxied it as HTTP to the Admin Nginx container.
2. **Admin Nginx (Layer 2)**: Was configured with `proxy_set_header X-Forwarded-Proto $scheme;`. Since the internal connection was HTTP, it sent `X-Forwarded-Proto: http` to the backend.
3. **Django Backend (Layer 3)**: Has `SECURE_SSL_REDIRECT = True`. It saw the `http` header and issued a redirect to `https`.
4. **The Loop**: Nginx received the backend's redirect and passed it back to Caddy, which passed it to the browser. The browser followed it, hitting Nginx again, which again told the backend it was "http", triggering another redirect.

## 3. Resolution Strategy

### Solution A: Protocol Hardcoding (Implemented)
- **Action**: Forced `proxy_set_header X-Forwarded-Proto https;` in the Admin Nginx configuration.
- **Rationale**: Since the public entry point (Caddy) is strictly HTTPS, we ensure the backend always knows the original request was secure, bypassing Django's internal redirect logic.

### Solution B: Protocol Pass-through (Recommended Alternative)
- **Action**: Use `proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;`.
- **Rationale**: This preserves the header sent by Caddy. If Caddy received HTTPS, it passes HTTPS. This is more flexible for hybrid environments.

### Solution C: Absolute Redirect Suppression
- **Action**: Set `absolute_redirect off;` in Nginx.
- **Rationale**: Prevents Nginx from automatically prepending the protocol/hostname to redirects (like trailing slash corrections), making redirects relative and protocol-agnostic.

## 4. Verification Results
- `https://blogadmin.hbca.tech/login/` -> **200 OK** (served by backend proxy).
- `https://blogadmin.hbca.tech/login` -> **200 OK** (served as frontend SPA).
- Verified via `curl -v` observing the full header chain.

## 5. Lessons Learned
- **Multi-Hop Header Integrity**: In nested proxies (Caddy -> Nginx -> Gunicorn), the `X-Forwarded-Proto` header must be explicitly preserved or hardcoded to the public protocol to prevent framework-level redirect loops.
- **Relative Redirects**: Always disable `absolute_redirect` in Nginx when running behind an SSL-terminating load balancer to ensure internal path corrections don't break the protocol state.
