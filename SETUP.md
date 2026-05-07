# Auto-Logging Setup Guide

This document explains how Claude Code and Gemini CLI are configured to automatically log production issues.

## Overview

When you debug production problems using Claude Code or Gemini CLI, they will automatically create detailed issue logs in this repository without you having to ask.

## How It Works

### Claude Code Configuration

#### 1. Project-Level Config
Each project has a `CLAUDE.md` file that includes auto-logging instructions:

```
C:\Users\Dell\Documents\projects\CRM\crm\CLAUDE.md
```

#### 2. Local Config (Not in Git)
Each project has a `.claude/auto-logging.md` file with project-specific details:

```
C:\Users\Dell\Documents\projects\CRM\crm\.claude\auto-logging.md
```

This file specifies:
- Project name
- Dev-logs path
- VPS connection details
- When to auto-log
- Log format

#### 3. How Claude Uses It
When you work on debugging:
1. Claude reads the `CLAUDE.md` file
2. Detects you're fixing a production issue
3. Creates an issue log automatically
4. Fills in details from the conversation
5. Commits to dev-logs repo

### Gemini CLI Configuration

#### 1. Global Config
Updated enterprise policy at:
```
C:\Users\Dell\.gemini\enterprise.md
```

Added Section 6: Automatic Issue Logging

#### 2. Detailed Instructions
Full logging guide at:
```
C:\Users\Dell\.gemini\ISSUE_LOGGING.md
```

Includes:
- Project path mapping
- Auto-logging rules
- Step-by-step process
- PowerShell examples

#### 3. How Gemini Uses It
1. Reads enterprise.md on startup
2. Maps current directory to project
3. Detects production issue resolution
4. Creates log using template
5. Commits to dev-logs repo

## Project Mapping

| Current Directory | Dev Logs Folder | Project Name |
|------------------|-----------------|--------------|
| `C:\Users\Dell\Documents\projects\CRM\*` | `dev-logs\CRM\` | CRM Professional |
| `C:\Users\Dell\Documents\projects\HBEC\*` | `dev-logs\HBEC\` | HBEC Student |
| `C:\Users\Dell\Documents\projects\SMEPULSE\*` | `dev-logs\SMEPULSE\` | SMEPulse |
| `C:\Users\Dell\Documents\projects\New Tesee\*` | `dev-logs\Tese\` | Tese Marketplace |

## What Gets Auto-Logged

### ✅ Automatically Logged
- Production service outages
- Container/Docker failures
- SSH debugging sessions
- Deployment script errors
- Critical errors affecting users
- Permission/configuration issues
- Database migration problems

### ❌ Not Auto-Logged
- Feature development
- Simple code changes
- Documentation updates
- Questions/discussions
- Routine maintenance

## Manual Logging

### Quick Script
```powershell
# From any project directory
C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Title "backend-crash" -Severity Critical
```

The script:
- Auto-detects project
- Creates file with today's date
- Copies template
- Opens in editor
- Provides commit commands

### Manual Process
```powershell
cd C:\Users\Dell\Documents\projects\dev-logs

# Copy template
$date = Get-Date -Format "yyyy-MM-dd"
Copy-Item templates\issue-template.md CRM\$date-issue-name.md

# Edit the file
code CRM\$date-issue-name.md

# Commit
git add CRM\$date-issue-name.md
git commit -m "CRM: Document [issue]"
git push
```

## File Structure

```
dev-logs/
├── README.md                    # Main docs
├── SETUP.md                     # This file
├── log-issue.ps1                # Helper script
├── .gitignore                   # Git ignore rules
├── CRM/
│   ├── README.md                # CRM index
│   └── 2026-05-07-backend-crash-loop-static-files-permissions.md
├── HBEC/
│   └── README.md
├── SMEPULSE/
│   └── README.md
├── Tese/
│   └── README.md
└── templates/
    └── issue-template.md        # Standard template
```

## Configuration Files

### Claude Code
- `[project]/CLAUDE.md` - Project instructions (in git)
- `[project]/.claude/auto-logging.md` - Local config (not in git)

### Gemini CLI
- `C:\Users\Dell\.gemini\enterprise.md` - Global policy
- `C:\Users\Dell\.gemini\ISSUE_LOGGING.md` - Logging instructions

## Testing

To test auto-logging:

1. **Create a test issue:**
   ```powershell
   cd C:\Users\Dell\Documents\projects\CRM\crm
   C:\Users\Dell\Documents\projects\dev-logs\log-issue.ps1 -Title "test-issue" -Severity Low
   ```

2. **Verify in Claude:**
   - Open Claude Code in CRM project
   - Say: "I just fixed a backend crash loop"
   - Claude should mention creating an issue log

3. **Verify in Gemini:**
   - Open Gemini CLI in CRM project
   - Say: "Document the backend crash we just fixed"
   - Gemini should create the log automatically

## Workflow Example

### Real-World Scenario

```
User: "The CRM site is down with ERR_INVALID_RESPONSE"

[Claude/Gemini debugging session...]

Claude/Gemini:
1. Runs diagnostics
2. Finds backend crash loop
3. Fixes permissions
4. Restarts services
5. Verifies site is up
6. **Automatically creates:**
   C:\Users\Dell\Documents\projects\dev-logs\CRM\2026-05-07-backend-crash-loop.md

7. Fills in:
   - Summary
   - Error messages
   - Commands used
   - Root cause
   - Solution
   - Prevention steps

8. Commits to git:
   ```
   git commit -m "CRM: Document backend crash loop due to permissions"
   ```

User: "Great, thanks!"
```

## Benefits

1. **No Manual Work:** Just fix the issue, logging happens automatically
2. **Complete Records:** All debugging steps captured during the session
3. **Consistent Format:** Every log follows the same template
4. **Searchable:** Git history + GitHub search
5. **Team Knowledge:** Share solutions across projects
6. **Pattern Detection:** Spot recurring issues

## Customization

### Adding a New Project

1. **Create project folder:**
   ```powershell
   mkdir C:\Users\Dell\Documents\projects\dev-logs\[PROJECT_NAME]
   ```

2. **Create README:**
   ```powershell
   # Copy from another project and customize
   cp dev-logs\CRM\README.md dev-logs\[PROJECT_NAME]\README.md
   ```

3. **Update mappings:**
   - Add to `log-issue.ps1` $PROJECT_MAP
   - Add to `.gemini\ISSUE_LOGGING.md` project table
   - Create `.claude\auto-logging.md` in project

4. **Update README:**
   - Add link to main `dev-logs\README.md`

## Troubleshooting

### "Claude/Gemini didn't create a log"

- Check if issue qualifies (production, critical, etc.)
- Verify project has CLAUDE.md or is in Gemini's mapping
- Manually ask: "Please log this issue to dev-logs"

### "Log created in wrong folder"

- Check project mapping in configs
- Verify current working directory
- Use `-Project` parameter with log-issue.ps1

### "Template not found"

- Ensure template exists: `dev-logs\templates\issue-template.md`
- Check paths in auto-logging configs

## Next Steps

1. **Push to GitHub:**
   ```bash
   cd C:\Users\Dell\Documents\projects\dev-logs
   git remote add origin https://github.com/YOUR_USERNAME/dev-logs.git
   git push -u origin main
   ```

2. **Set up other projects:**
   - Create `.claude/auto-logging.md` for HBEC, SMEPULSE, etc.
   - Update CLAUDE.md files

3. **Test the system:**
   - Create a test log
   - Verify auto-detection works
   - Practice the workflow

---

**Created:** 2026-05-07
**Last Updated:** 2026-05-07
