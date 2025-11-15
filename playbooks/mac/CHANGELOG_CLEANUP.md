# macOS Playbook Cleanup Changelog

**Date**: 2025-11-15
**Reason**: Simplify playbook, remove broken/unused components that were causing CI failures

## Summary of Changes

Cleaned up the macOS personal playbook to focus on what actually works:
- Modern shell configuration (common-shell role)
- Homebrew package management
- Optional system preferences and app configs

## What Was REMOVED

### 1. Ansible Setup Tasks (`tasks/mac/ansible-setup.yml`)
**Removed**: Entire task import
**Why**:
- Created `/etc/ansible` directory (requires sudo, not needed for basic setup)
- Created downloads directory (already created by Homebrew role)
- Had commented-out symlink that was never used
- Not essential for shell configuration

### 2. Sudoers Configuration (`tasks/mac/sudoers.yml`)
**Removed**: Entire task import
**Why**:
- Referenced non-existent `templates/sudoers.j2` template file
- Requires sudo access
- Was for "convenient Vagrant usage" - niche use case
- Not related to shell configuration
- **Causing CI failures**

### 3. Dock Restart Handler
**Removed**: Handler definition
**Why**:
- Not triggered by any tasks in the simplified playbook
- Was only needed for macOS system preference changes
- mac-system role likely has its own handlers if needed

### 4. Variables Removed from `vars/personal.yml`

#### `dotfiles_home: "~"`
- **Why**: Unused variable, no tasks referenced it

#### `dotfiles_files: [.gitconfig, .to_be_installed, .zshrc]`
- **Why**: Not used by any role or task
- References `.to_be_installed` directory that doesn't exist
- Modern setup uses symlinks via common-shell role, not this list

#### `vim_script: "~/.to_be_installed/vim/install.sh"`
- **Why**: References non-existent path
- app-config role handles vim if enabled
- Not used in default configuration

#### Feature toggle values (commented out, not removed entirely)
- **Changed**: From explicit `yes`/`no` to comments explaining they should be set in inventory
- **Why**:
  - vars_files has higher precedence than inventory
  - Was preventing CI test overrides
  - Better to use role defaults and inventory-specific overrides

### 5. YAML Boolean Values
**Changed**: `yes`/`no` → `true`/`false`
**Why**:
- Ansible best practice
- Better compatibility with YAML parsers
- Fixes ansible-lint warnings

## What Was CHANGED

### 1. Module Names
**Changed**: All module calls use FQCN (Fully Qualified Collection Names)
- `debug` → `ansible.builtin.debug`
- `import_tasks` → `ansible.builtin.import_tasks`
- `include_tasks` → `ansible.builtin.include_tasks`

**Why**: Ansible best practice, required by moderate ansible-lint profile

### 2. Extra Packages Task
**Added**: Conditional to only run if packages are defined
```yaml
when: >
  (composer_packages | default([]) | length > 0) or
  (npm_packages | default([]) | length > 0) or
  (pip_packages | default([]) | length > 0) or
  (gem_packages | default([]) | length > 0)
```
**Why**: No point running if all lists are empty (default case)

### 3. Role Conditionals
**Enhanced**: All optional roles now have proper `when` conditions
- `mac-system`: `when: configure_osx | default(false)`
- `app-config`: `when: (configure_sublime | default(false)) or ...`

**Why**: Prevents roles from running when not needed (especially in CI)

## Current Playbook Structure

```yaml
Pre-tasks:
  - Display deployment info

Roles:
  1. geerlingguy.mac.homebrew (always)
  2. common-shell (always) - Modern shell setup
  3. mac-system (conditional) - macOS preferences
  4. app-config (conditional) - App configurations

Tasks:
  1. extra-packages (conditional) - Only if packages defined
  2. post-provision (conditional) - Only if tasks defined

Post-tasks:
  - Display completion message
```

## What Still Works

✅ Modern shell configuration (zinit, starship, modern tools)
✅ Homebrew package installation
✅ Homebrew cask app installation
✅ macOS system preferences (if enabled)
✅ Sublime Text / iTerm2 / Vim config (if enabled)
✅ Extra packages (composer, npm, pip, gem) if specified
✅ Post-provision custom tasks

## Breaking Changes for Users

⚠️ **If you were relying on**:
- `/etc/ansible` directory creation → Need to create manually or add back
- Sudoers configuration → Need to create template and re-add task
- `.to_be_installed` directory → Need different approach for vim/configs

✅ **Migration Path**:
Most users won't notice - these were niche features that weren't commonly used.
Core functionality (shell + homebrew) is unchanged.

## CI/Testing Impact

✅ **Fixed Issues**:
1. No more missing template errors (sudoers.j2)
2. No more sudo-required tasks in CI
3. Proper variable precedence (inventory can override)
4. Cleaner, faster test runs

✅ **Test Coverage**:
- CI tests now pass with minimal configuration
- All core functionality tested
- Optional features properly skipped in CI

## Future Improvements

Consider:
1. Move extra-packages to its own role for better organization
2. Create separate "development" vs "personal" playbooks
3. Document common use cases and examples
4. Add validation for required variables
