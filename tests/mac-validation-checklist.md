# Mac Playbook Validation Checklist

This checklist provides step-by-step validation procedures for Mac playbooks, which cannot be fully tested in Docker containers due to macOS-specific dependencies.

## Pre-Testing Preparation

### Backup
- [ ] Create Time Machine backup before running playbook
- [ ] Commit any uncommitted changes in dotfiles repository
- [ ] Document current system state (take screenshots of Dock, Finder preferences)

### Dependencies
- [ ] Ensure Ansible is installed: `ansible --version`
- [ ] Install Ansible Galaxy dependencies: `ansible-galaxy install -r requirements.yml`
- [ ] Verify Git is configured with proper user.name and user.email

## Testing Order

**Recommended**: Test on old MacBook (2015 personal laptop) first, then work laptop last.

1. Old MacBook (low risk)
2. Work laptop (after everything validated)

---

## Phase 1: Pre-Flight Check (Check Mode)

Run playbook in check mode to preview changes without applying them.

### Personal Mac (`playbooks/mac/personal.yml`)

```bash
cd ~/Development/terminal_improvements/ansible-playbooks
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K --check
```

- [ ] Check mode completes without errors
- [ ] Review planned changes in output
- [ ] No unexpected file deletions or modifications

### Work Mac (`playbooks/mac/work.yml`)

```bash
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K --check
```

- [ ] Check mode completes without errors
- [ ] Work-tasks role found and loaded
- [ ] Review work-specific changes

---

## Phase 2: Apply Playbook

Apply the playbook to the Mac.

### Personal Mac

```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K -vv
```

**Monitor for**:
- [ ] No errors during execution
- [ ] Homebrew installations complete successfully
- [ ] Dotfiles symlinked correctly
- [ ] All roles complete successfully

### Work Mac

```bash
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K -vv
```

**Monitor for**:
- [ ] Personal role tasks complete
- [ ] Work-tasks role executes
- [ ] N26-specific configurations applied

---

## Phase 3: Validation After Apply

### 3.1 Shell Configuration

Open a new terminal window and verify:

```bash
# Check zsh is default shell
echo $SHELL
# Expected: /bin/zsh

# Check Starship prompt appears
# Expected: Blue λ for personal, Cyan λ for work

# Check machine type detection
echo "Machine type detection test - check prompt character"
```

- [ ] Zsh loads without errors
- [ ] Starship prompt renders correctly
- [ ] Correct prompt character (λ for laptops)
- [ ] Correct color (blue for personal, cyan for work/pro)
- [ ] No plugin errors in terminal output

### 3.2 Shell Startup Performance

```bash
# Measure startup time (target: <100ms)
time zsh -i -c exit
time zsh -i -c exit
time zsh -i -c exit
```

- [ ] Average startup time < 100ms
- [ ] Significantly faster than old Prezto config (baseline: 200-300ms)

### 3.3 Modern Tools

Verify all tools are installed and working:

```bash
# Essential tools
which starship && starship --version
which fzf && fzf --version
which zoxide && zoxide --version
which rg && rg --version

# Laptop tools
which bat && bat --version
which eza && eza --version
which fd && fd --version
```

- [ ] Starship installed and working
- [ ] fzf installed (test with Ctrl+R for history search)
- [ ] zoxide installed (test with `z` command)
- [ ] ripgrep installed
- [ ] bat installed
- [ ] eza installed
- [ ] fd installed

### 3.4 Zinit Plugin Manager

```bash
# Check zinit installation
ls -la ~/.local/share/zinit/zinit.git

# Test plugin loading (start new shell and check for errors)
exec zsh
```

- [ ] Zinit directory exists
- [ ] Plugins load without errors
- [ ] zsh-autosuggestions working (type partial command, see gray suggestion)
- [ ] zsh-syntax-highlighting working (commands turn green when valid)

### 3.5 Homebrew Packages (Personal & Work)

```bash
# Check installed packages
brew list

# Verify key packages for personal
brew list | grep -E "(git|zsh|fzf|ripgrep|bat|eza|fd)"

# Verify work-specific packages (work Mac only)
brew list | grep -E "(terraform|kubectl|helm|k9s)"
```

**Personal Mac**:
- [ ] Git installed via Homebrew
- [ ] Development tools installed
- [ ] Fonts installed (check `~/Library/Fonts/` for Menlo Powerline)

**Work Mac** (additional):
- [ ] Terraform installed
- [ ] kubectl installed
- [ ] Helm installed
- [ ] k9s installed
- [ ] Work-specific tools from N26 playbook

### 3.6 macOS System Preferences

Check that macOS preferences were applied:

**Dock**:
- [ ] Dock auto-hide enabled
- [ ] Dock position (left/bottom as configured)
- [ ] Icon size appropriate
- [ ] No recent apps shown

**Finder**:
- [ ] Show all filename extensions enabled
- [ ] Show hidden files (Cmd+Shift+. to toggle)
- [ ] Default view set to list view
- [ ] Path bar shown at bottom

**Trackpad**:
- [ ] Tap to click enabled
- [ ] Three-finger drag enabled (or as configured)

**Keyboard**:
- [ ] Key repeat rate fast
- [ ] Delay until repeat short

To verify settings:
```bash
# Check specific defaults
defaults read com.apple.dock autohide
defaults read NSGlobalDomain AppleShowAllExtensions
```

### 3.7 Application Configurations

**Sublime Text** (if installed):
- [ ] Configuration files linked to `~/.config/sublime-text-3/`
- [ ] Open Sublime and check settings applied

**iTerm2** (if installed):
- [ ] Profile imported
- [ ] Color scheme applied
- [ ] Font set to Menlo Powerline or configured font

**Vim**:
- [ ] `.vimrc` exists and loads without errors
- [ ] Plugins installed (if using vim-plug or similar)

```bash
# Test vim configuration
vim ~/.vimrc
# Should load without errors
```

### 3.8 Git Configuration

```bash
# Verify git config
git config --list | grep user
git config --list | grep core.editor

# Check .gitconfig
cat ~/.gitconfig
```

- [ ] user.name set correctly
- [ ] user.email set correctly
- [ ] Default editor configured
- [ ] Git aliases working

### 3.9 Work-Specific Validation (Work Mac Only)

```bash
# Check work environment file
cat ~/.config/zsh/profiles/pro/n26env.sh

# Verify work tools
which terraform
which kubectl
which helm
which k9s

# Test work environment variables loaded
echo $JENKINS_URL  # or other work-specific env vars
```

- [ ] N26 environment variables file exists
- [ ] Work tools installed and in PATH
- [ ] Work-specific aliases available
- [ ] SSO/credentials configured (if applicable)

---

## Phase 4: Idempotency Test

Run the playbook a second time to verify idempotency (no changes).

```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
# OR for work Mac:
ansible-playbook playbooks/mac/work.yml -i inventories/localhost -K
```

- [ ] Playbook completes successfully
- [ ] Output shows `changed=0` or minimal changes
- [ ] No unexpected modifications

---

## Phase 5: Regression Testing

Test common development workflows:

### Development Tools
```bash
# Test Git
git status
git clone <test-repo>

# Test Python environment (if configured)
python3 --version

# Test Node.js (if configured)
node --version
npm --version

# Test Docker (if installed)
docker --version
docker ps
```

- [ ] Git operations work normally
- [ ] Development tools accessible
- [ ] No PATH issues

### Shell Features
```bash
# Test fzf history search
# Press Ctrl+R and type to search command history

# Test zoxide directory jumping
z <directory-name>

# Test modern tools
eza -la  # should work as modern ls
bat ~/.zshrc  # should show syntax highlighting
```

- [ ] fzf history search works (Ctrl+R)
- [ ] zoxide directory jumping works
- [ ] Modern tool aliases work

---

## Phase 6: Performance Benchmarking

### Shell Startup Time
```bash
# Run 10 times and average
for i in {1..10}; do time zsh -i -c exit; done 2>&1 | grep real
```

- [ ] Record average startup time
- [ ] Compare to baseline (old Prezto: ~200-300ms)
- [ ] Target achieved (<100ms)

### Plugin Loading
```bash
# Check zinit load time
zinit times
```

- [ ] Review plugin load times
- [ ] Identify any slow plugins

---

## Troubleshooting

### Common Issues

**Issue**: Starship prompt not showing
- Check `~/.config/starship.toml` exists
- Verify `eval "$(starship init zsh)"` in `.zshrc`
- Run `starship config` to validate configuration

**Issue**: Plugins not loading
- Check `~/.local/share/zinit/zinit.git` exists
- Review `.zshrc` for zinit initialization
- Run `zinit update` to update plugins

**Issue**: Homebrew packages missing
- Run `brew bundle check` to verify installations
- Review Homebrew output for errors
- Check `vars/personal.yml` or `vars/work.yml` for package list

**Issue**: macOS preferences not applied
- Some preferences require logout/restart
- Verify `defaults` commands in playbook output
- Manually check System Preferences

**Issue**: Slow shell startup
- Run `zinit times` to profile plugin load times
- Disable heavy plugins in profile config
- Check for large history files

### Rollback Procedure

If major issues occur:

1. **Restore dotfiles**:
   ```bash
   cd ~/Development/terminal_improvements/dotfiles
   git checkout <previous-commit>
   ```

2. **Restore from Time Machine backup** (if system-level issues)

3. **Remove installed tools**:
   ```bash
   brew uninstall starship fzf zoxide bat eza fd
   ```

4. **Revert to old shell config**:
   ```bash
   cd ~/Development/terminal_improvements/dotfiles
   git checkout legacy/zpreztorc
   ln -sf ~/Development/terminal_improvements/dotfiles/legacy/zpreztorc ~/.zpreztorc
   ```

---

## Sign-Off

After completing all validation steps:

- [ ] All checks passed
- [ ] Performance targets met
- [ ] No regressions detected
- [ ] System stable and usable
- [ ] Ready to deploy to next machine

**Tester**: ___________________________
**Date**: ___________________________
**Machine**: ___________________________ (Personal/Work)
**Result**: ___________________________ (Pass/Fail)

**Notes**:
```
[Space for observations, issues, or recommendations]
```

---

## Next Steps After Validation

If all checks pass on the test Mac:
1. Document any issues or improvements in GitHub Issues
2. Update playbook variables if needed
3. Proceed to next machine in rollout plan
4. Update STATUS.md with deployment progress

If issues found:
1. Document issues in detail
2. Fix playbook or role as needed
3. Re-test on same machine
4. Do not proceed to next machine until resolved
