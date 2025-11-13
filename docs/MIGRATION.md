# Migration Guide

**Last Updated**: 2025-11-13

This guide helps you migrate from the old repository structure to the new consolidated `ansible-playbooks/` repository.

## Table of Contents

- [Overview](#overview)
- [What Changed](#what-changed)
- [Migration Path by Use Case](#migration-path-by-use-case)
- [Rollback Instructions](#rollback-instructions)

---

## Overview

The consolidation project merged 4 separate Ansible repositories into a single DRY architecture:

- **ansible-roles/** → **ansible-playbooks/** (renamed, expanded)
- **mac-dev-playbook/** → Migrated into `ansible-playbooks/` (will be deleted in Phase 7)
- **mac-playbook-work/** → Kept separate (work-sensitive)
- **infra/ansible/** → Kept separate but references shared roles

### Benefits

1. **DRY** - Shell/system config defined once, used everywhere
2. **Consistency** - Same modern shell across all environments
3. **Maintainability** - Clear structure, one place to update
4. **Work Isolation** - Sensitive configs stay in private repo

---

## What Changed

### Repository Structure

**Before**:
```
terminal_improvements/
├── ansible-roles/          # Shared shell role only
├── mac-dev-playbook/       # Personal Mac automation
├── mac-playbook-work/      # Work-specific (separate)
└── infra/ansible/          # Server automation
```

**After**:
```
terminal_improvements/
├── ansible-playbooks/      # ✨ CENTRAL consolidated repo
│   ├── roles/              # Shared roles (4 roles now)
│   ├── playbooks/          # Organized by platform
│   ├── tasks/              # Shared task files
│   └── inventories/        # Example inventories
├── mac-playbook-work/      # Still separate (work-sensitive)
└── infra/ansible/          # Still separate, uses shared roles
```

### File Mappings

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `ansible-roles/roles/common-shell/` | `ansible-playbooks/roles/common-shell/` | Unchanged |
| `mac-dev-playbook/main.yml` | `ansible-playbooks/playbooks/mac/personal.yml` | Rewritten |
| `mac-dev-playbook/tasks/osx.yml` | `ansible-playbooks/roles/mac-system/` | Extracted to role |
| `mac-dev-playbook/tasks/sublime.yml` | `ansible-playbooks/roles/app-config/` | Extracted to role |
| `infra/ansible/ubuntu/base/*.yml` | `ansible-playbooks/roles/server-base/` | Extracted to role |

---

## Migration Path by Use Case

### If You Were Using: `mac-dev-playbook`

**Old Command**:
```bash
cd ~/Development/terminal_improvements/mac-dev-playbook
make install
```

**New Command**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
```

**What to Do**:
1. Install dependencies: `ansible-galaxy install -r requirements.yml`
2. Review variables in `playbooks/mac/vars/personal.yml`
3. Customize if needed (packages, apps, toggles)
4. Run the new playbook
5. Test that everything works
6. Delete old `mac-dev-playbook/` directory (Phase 7)

---

### If You Were Using: `mac-playbook-work` (Work Laptop)

**Old Command**:
```bash
cd ~/Development/terminal_improvements/mac-playbook-work
make install
```

**New Command**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K
```

**What Changed**:
- `mac-playbook-work/` still exists as a separate repo
- It's now referenced as a role (`work-tasks`) by the work playbook
- Non-sensitive work tooling (terraform, kubectl, helm) moved to shared config
- Sensitive N26 configs stay in private `mac-playbook-work/`

**What to Do**:
1. Ensure `mac-playbook-work/` repo is still cloned
2. Install dependencies (includes work-tasks role)
3. Review `playbooks/mac/vars/work.yml`
4. Run the work playbook
5. Verify N26-specific tasks still work

---

### If You Were Using: `infra/ansible` (Servers)

**Old Command**:
```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu
ansible-playbook base.yml -i inventory.yaml
```

**New Command** (same, but now uses shared roles):
```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu
ansible-playbook base.yml -i inventory.yaml
```

**What Changed**:
- `base.yml` now uses `server-base` role from ansible-playbooks
- `shell-setup.yml` uses `common-shell` role (replaces oh-my-zsh.yml)
- `ansible.cfg` updated to point to shared roles

**What to Do**:
1. No immediate action required
2. Old task files still work (commented out in base.yml)
3. Gradually migrate to using shell-setup.yml for modern shell
4. Eventually delete `base/oh-my-zsh.yml`

---

### If You Were Using: Standalone Playbooks (`ansible-roles/playbooks/`)

**Old Commands**:
```bash
cd ~/Development/terminal_improvements/ansible-roles
make wsl
make laptop
make server
```

**New Commands**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/wsl/setup.yml -i inventories/localhost
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
ansible-playbook playbooks/servers/shell.yml -i inventories/servers.yml
```

**What Changed**:
- Playbooks moved to subdirectories by platform
- More comprehensive Mac playbooks (not just shell)
- Servers have two playbooks: base.yml + shell.yml

---

## Rollback Instructions

If something goes wrong during migration:

### Option 1: Restore from Backup

```bash
cd ~/Development/terminal_improvements
tar -xzf ~/ansible-consolidation-backup-*.tar.gz
```

### Option 2: Use Old Repository (Until Phase 7)

```bash
# mac-dev-playbook still exists until Phase 7
cd ~/Development/terminal_improvements/mac-dev-playbook
make install
```

### Option 3: Revert Infra Changes

```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu

# Edit base.yml - uncomment old task imports
vim base.yml

# Revert ansible.cfg roles_path
vim ansible.cfg
```

---

## Verification Checklist

After migration, verify:

- [ ] `ansible-playbooks/` repository exists
- [ ] Dependencies installed: `ansible-galaxy install -r requirements.yml`
- [ ] Playbook runs successfully (--check mode first)
- [ ] Shell loads with correct prompt character (λ, !, ·)
- [ ] Modern tools available: `which fzf zoxide starship`
- [ ] Zinit plugins loaded: `zinit list`
- [ ] No errors in Ansible output
- [ ] Work configs functional (work laptop only)

---

## Common Issues

### Issue: "Role 'common-shell' not found"

**Solution**: Install dependencies
```bash
cd ansible-playbooks
ansible-galaxy install -r requirements.yml
```

### Issue: "work-tasks role not found"

**Solution**: Ensure mac-playbook-work repo exists
```bash
ls ~/Development/terminal_improvements/mac-playbook-work
ansible-galaxy install -r requirements.yml  # Installs from git
```

### Issue: "Variables undefined in playbook"

**Solution**: Check vars files exist
```bash
ls playbooks/mac/vars/personal.yml
vim playbooks/mac/vars/personal.yml  # Customize as needed
```

### Issue: "Permission denied" on sudoers task

**Solution**: Run with -K flag
```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
# Enter sudo password when prompted
```

---

## Need Help?

- Check `docs/PLAYBOOKS.md` for playbook usage
- Check `docs/ROLES.md` for role documentation
- Review `docs/INTEGRATION.md` for infra integration
- See consolidation plan: `_doc/ansible_consolidation_plan.md`
