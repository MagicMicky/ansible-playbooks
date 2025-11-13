# Testing Checklist

**Status**: Ready for Phase 6 Testing
**Date**: 2025-11-13

## Pre-Testing Validation ✅

All items below have been validated:

- ✅ Playbook syntax validation passed
  - ✅ `playbooks/mac/personal.yml` - Valid
  - ✅ `playbooks/mac/work.yml` - Valid (requires work-tasks role)
  - ✅ `playbooks/wsl/setup.yml` - Valid
  - ✅ `playbooks/servers/base.yml` - Valid
  - ✅ `playbooks/servers/shell.yml` - Valid

- ✅ Role structure validated
  - ✅ 4 roles with main.yml files
  - ✅ All defaults/main.yml files present
  - ✅ All handlers where needed

- ✅ Variable files exist
  - ✅ `playbooks/mac/vars/personal.yml`
  - ✅ `playbooks/mac/vars/work.yml`
  - ✅ `playbooks/servers/vars/defaults.yml`

- ✅ Configuration files
  - ✅ `requirements.yml` - Valid YAML
  - ✅ `ansible.cfg` - Present
  - ✅ Inventories created

- ✅ Work repository available
  - ✅ `mac-playbook-work/` exists at correct path

---

## Phase 6: Actual Testing

### Step 1: Install Dependencies

**Command**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-galaxy install -r requirements.yml --force
```

**Expected Output**:
- Install community.general collection
- Install geerlingguy.mac collection
- Install geerlingguy.dotfiles role
- Install elliotweiser.osx-command-line-tools role
- Clone work-tasks role from mac-playbook-work repo

**Validation**:
```bash
ansible-galaxy collection list | grep community.general
ansible-galaxy collection list | grep geerlingguy.mac
ansible-galaxy role list | grep geerlingguy.dotfiles
ansible-galaxy role list | grep work-tasks
```

---

### Step 2: Test WSL Playbook (Recommended First)

**Why first**: Current machine, low risk, Linux environment

**Command (Dry Run)**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/wsl/setup.yml --check -vv
```

**What to Check**:
- [ ] No syntax errors
- [ ] No missing variables
- [ ] All tasks would execute (in theory)
- [ ] common-shell role found and loaded
- [ ] No file path issues

**Expected Changes** (if run for real):
- Clone/update dotfiles repo
- Install Starship prompt
- Install fzf, zoxide, ripgrep
- Configure zsh with zinit
- Link shell configs

**If Dry Run Passes**:
```bash
# Actual run (only if confident!)
ansible-playbook playbooks/wsl/setup.yml -vv

# After completion
exec zsh  # Restart shell
echo $MACHINE_TYPE  # Should be "wsl"
# Prompt should show blue [λ]
```

---

### Step 3: Test Personal Mac Playbook

**Platform**: macOS only
**Risk**: Medium (backs up configs, but changes system)

**Command (Dry Run)**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check -vv
```

**What to Check**:
- [ ] Prompts for sudo password (-K flag)
- [ ] No missing variables
- [ ] All roles found (common-shell, mac-system, app-config)
- [ ] Homebrew tasks would execute
- [ ] File paths correct for dotfiles

**Expected Changes** (if run for real):
- Install Homebrew packages
- Configure modern shell
- Set macOS system preferences
- Install Powerline fonts
- Link Sublime/iTerm/Vim configs

**Manual Review Before Actual Run**:
1. Check `playbooks/mac/vars/personal.yml` - customize packages/apps
2. Backup important files: `~/.zshrc`, `~/Library/Preferences/`
3. Ensure dotfiles repo is on correct branch (`modern-shell-2025`)

**If Dry Run Passes**:
```bash
# Actual run (careful!)
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K -vv

# After completion
exec zsh
echo $MACHINE_TYPE  # Should be "personal"
# Prompt should show blue [λ]
time zsh -i -c exit  # Should be <100ms
```

---

### Step 4: Test Work Mac Playbook

**Platform**: macOS only
**Risk**: High (work laptop, critical system)
**Recommendation**: Test on old MacBook first!

**Command (Dry Run)**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --check -vv
```

**What to Check**:
- [ ] work-tasks role found (requires galaxy install)
- [ ] Extends personal.yml correctly
- [ ] Work packages listed (terraform, kubectl, etc.)
- [ ] N26-specific tasks would execute

**Expected Changes** (if run for real):
- Everything from personal.yml
- Install work tools (terraform, kubectl, helm, k9s)
- Run work-tasks role (N26 configs)
- Configure pro profile

**Critical Pre-Flight**:
1. ⚠️ **BACKUP EVERYTHING** on work laptop
2. Test on old MacBook first
3. Review work-tasks role for breaking changes
4. Ensure VPN/work tools are backed up
5. Have rollback plan ready

---

### Step 5: Test Server Base Playbook

**Platform**: Ubuntu/Debian servers
**Risk**: Low (idempotent, reversible)

**Command (Dry Run)**:
```bash
cd ~/Development/terminal_improvements/ansible-playbooks

# Create test inventory first
cat > inventories/test-servers.yml <<EOF
all:
  hosts:
    test-server:
      ansible_host: localhost
      ansible_connection: local
EOF

ansible-playbook playbooks/servers/base.yml -i inventories/test-servers.yml --check -vv
```

**What to Check**:
- [ ] server-base role loaded
- [ ] Package installation tasks
- [ ] Docker installation tasks
- [ ] User creation tasks
- [ ] SSH key tasks

**Expected Changes** (if run for real):
- Install base packages (git, htop, zsh, curl)
- Install Docker and Docker Compose
- Create users (magicmicky, ansible)
- Add SSH keys
- Configure passwordless sudo

---

### Step 6: Test Server Shell Playbook

**Command (Dry Run)**:
```bash
ansible-playbook playbooks/servers/shell.yml -i inventories/test-servers.yml --check -vv
```

**What to Check**:
- [ ] common-shell role loaded
- [ ] Minimal tools only (no bat, eza, fd)
- [ ] Starship, fzf, zoxide installation

**Expected Changes** (if run for real):
- Install minimal shell config
- Configure server profile
- Starship with appropriate character (!, ·)
- Fast startup (<50ms target)

---

### Step 7: Test Infra Integration

**Location**: `infra/ansible/ubuntu/`

**Command (Dry Run)**:
```bash
cd ~/Development/terminal_improvements/infra/ansible/ubuntu
ansible-playbook base.yml -i inventory.yaml --check -vv
```

**What to Check**:
- [ ] Finds shared roles via ansible.cfg
- [ ] server-base role loaded successfully
- [ ] No path issues
- [ ] Legacy tasks commented out correctly

---

## Validation After Deployment

### Shell Validation

Run on each deployed machine:

```bash
# Check shell startup time
time zsh -i -c exit
# Target: <100ms (laptops), <50ms (servers)

# Check machine type detection
echo $MACHINE_TYPE
# Should be: personal, pro, wsl, prod, dev-server, etc.

# Check Starship prompt character
# Personal laptop: [λ] blue
# Work laptop: [λ] cyan
# Production: [!] red
# Other servers: [·] colored

# Verify tools installed
which starship fzf zoxide
# Laptops should also have: bat, eza, fd, ripgrep

# Check zinit loaded
zinit list
# Should show plugins

# Test fzf
echo "test" | fzf --filter test
# Should work

# Test zoxide
zoxide query --list 2>/dev/null || echo "No history yet (normal)"
```

### System Validation (Mac)

```bash
# Check Dock size
defaults read com.apple.dock tilesize
# Should be: 45

# Check dark mode
defaults read Apple\ Global\ Domain AppleInterfaceStyle
# Should be: Dark

# Check fonts installed
ls ~/Library/Fonts/ | grep Menlo
# Should show 4 Menlo Powerline fonts

# Check Sublime linked
ls -la ~/Library/Application\ Support/Sublime\ Text/Packages/User/
# Should show symlinks to dotfiles

# Check iTerm preferences
ls -la ~/Library/Preferences/com.googlecode.iterm2.plist
# Should be symlink to dotfiles
```

### Docker Validation (Servers)

```bash
# Check Docker running
docker ps
# Should work (no permission errors)

# Check user in docker group
groups | grep docker
# Should show docker

# Check Docker Compose
docker compose version
# Should show v2.x (plugin version)
```

---

## Rollback Procedures

### If Something Goes Wrong

**Immediate Rollback**:
```bash
# Restore from backup (created in Phase 0)
cd ~/
tar -xzf ansible-consolidation-backup-*.tar.gz

# Use old mac-dev-playbook
cd ~/Development/terminal_improvements/mac-dev-playbook
make install
```

**Partial Rollback** (shell only):
```bash
# Restore old shell config
cd ~/Development/terminal_improvements/dotfiles
git checkout develop  # or whatever old branch
cp zsh/.zshrc ~/.zshrc
exec zsh
```

**Server Rollback**:
```bash
# Servers should be stateless - rebuild from Packer if needed
# Or manually revert packages
```

---

## Success Criteria

Mark complete when:

### WSL
- [ ] Shell starts successfully
- [ ] Blue [λ] prompt shown
- [ ] Startup time <100ms
- [ ] fzf, zoxide, starship work
- [ ] No errors in shell startup

### Personal Mac
- [ ] All Homebrew packages installed
- [ ] Shell configured correctly
- [ ] macOS preferences applied
- [ ] Fonts installed
- [ ] Apps configured
- [ ] Startup time <100ms

### Work Mac
- [ ] Everything from personal Mac
- [ ] Work tools installed (terraform, kubectl, etc.)
- [ ] N26 configs applied
- [ ] Pro profile active
- [ ] Work services functional

### Servers
- [ ] Base packages installed
- [ ] Docker running
- [ ] Users created with SSH access
- [ ] Shell configured (minimal)
- [ ] Startup time <50ms
- [ ] Correct prompt character (!, ·)

---

## Issues Found

Document any issues here during testing:

### Issue 1: [Title]
- **Symptom**:
- **Cause**:
- **Fix**:
- **Status**:

---

## Notes

- **Phase 6 Status**: Ready to begin
- **Recommended Order**: WSL → Old MacBook → Test Server → Production
- **DO NOT**: Deploy to work laptop until fully tested elsewhere
- **Backup**: Created in Phase 0, still available

---

**Last Updated**: 2025-11-13
**Next Action**: Run dependency installation, then WSL dry-run test
