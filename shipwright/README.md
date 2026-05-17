# Shipwright Issues Log

Deployment automation tool for VPS environments with Docker/systemd support.

## Project Info
- **Repository:** https://github.com/tinomupezeni/shipwright
- **Type:** DevOps/CI-CD Tool
- **Stack:** Rust, Docker, systemd, WebSockets
- **Production VPS:** 159.198.42.231

## Issue Index

### 2026-05-17
- **[Deployment Retry System Implementation](./2026-05-17-deployment-retry-system-implementation.md)** - High Severity
  - FOREIGN KEY constraint failure in deployment tracking
  - Database migration conflicts
  - Query mismatch between UUID and project name
  - Message replay buffer implementation
  - **Status:** ✅ Resolved - Full retry system deployed

## Summary Statistics

- **Total Issues Logged:** 1 session (4 sub-issues)
- **Critical Issues:** 0
- **High Severity:** 1
- **Resolution Rate:** 100%

## Key Features Implemented

### Deployment Retry System
- ✅ Database tracking of deployment attempts (SQLite V5 migration)
- ✅ `shipwright status` - Show detailed deployment status with failure info
- ✅ `shipwright retry` - Retry deployments without git push
- ✅ `shipwright version` - Display version information
- ✅ Message replay buffer for `shipwright watch` (200 message history)
- ✅ RESTful API endpoints for retry and status
- ✅ Enhanced error messages with retry instructions

### Technical Achievements
- Systematic debugging using 5 Whys methodology
- Fixed foreign key constraint issues
- Resolved API/CLI parameter mismatches
- Implemented WebSocket message buffering
- Production deployment on VPS

## Common Patterns

### Database Issues
- Always verify foreign key relationships before inserts
- Use UUIDs for FK constraints, names for queries
- Provide dual query methods (by UUID and by name)

### API Design
- Clear field naming to avoid confusion
- Consider both internal and external consumers
- Enhanced error messages for faster debugging

### Deployment
- Test migration compatibility before production
- Keep database backups before schema changes
- Use systematic debugging approaches (5 Whys)

## Related Documentation
- [Shipwright README](https://github.com/tinomupezeni/shipwright/blob/main/README.md)
- [Deployment Standards](../DEPLOYMENT-STANDARDS.md)

---

**Last Updated:** 2026-05-17
