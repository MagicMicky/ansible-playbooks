# Testing Infrastructure Improvement Plan

**Status**: Phase 1 Complete ✅ | Phase 2 In Progress 🔄
**Date Started**: 2025-11-15
**Last Updated**: 2025-11-15

## Overview

Multi-phase improvement to fix critical test independence issues, add comprehensive coverage, and establish best practices for the Ansible playbooks testing infrastructure.

---

## Phase 1: Fix Critical Test Independence Issues ✅ COMPLETE

**Goal**: Eliminate state pollution, properly utilize Docker containers, fix error handling

### Completed Items

#### 1.1 ✅ Restructured Test Runner for Container Isolation
**Implementation**: `tests/scripts/run-all-tests.sh`

**What Changed**:
- Completely rewrote test orchestrator
- Each playbook now runs in dedicated container:
  - WSL playbook → `wsl-test` container
  - Server playbook → `server-test` container
- Tests run sequentially (local), but each gets fresh state
- Matches CI's parallel isolation approach

**Test Execution Flow**:
```
Phase 1: Syntax Validation
  - Runs once (not container-specific)

Phase 2: WSL Playbook Tests (in wsl-test container)
  1. Check mode execution
  2. Apply mode execution
  3. Shell validation
  4. Idempotency test

Phase 3: Server Playbook Tests (in server-test container)
  1. Check mode execution
  2. Apply mode execution
  3. Shell validation
  4. Idempotency test (NEW!)
```

**Results**:
- ✅ Zero state pollution
- ✅ Complete test independence
- ✅ 9/9 tests passing

#### 1.2 ✅ Fixed Problematic `failed_when: false` Uses

**Files Modified**: `roles/common-shell/tasks/configure-shell.yml`

##### Fix 1: bat theme download (lines 66-74)
**Before**:
```yaml
- name: Download Catppuccin Mocha bat theme
  get_url:
    url: "https://raw.githubusercontent.com/catppuccin/bat/..."
    dest: "{{ ansible_env.HOME }}/.config/bat/themes/Catppuccin Mocha.tmTheme"
  register: bat_theme_download
  failed_when: false  # ❌ Masked network/permission errors
```

**After**:
```yaml
- name: Download Catppuccin Mocha bat theme
  get_url:
    url: "https://raw.githubusercontent.com/catppuccin/bat/..."
    dest: "{{ ansible_env.HOME }}/.config/bat/themes/Catppuccin Mocha.tmTheme"
  register: bat_theme_download
  when: not ansible_check_mode  # ✅ Skip in check mode (dir doesn't exist yet)
  # Real errors now fail properly
```

**Why**: In check mode, directories report "changed" but don't actually exist. Skipping download in check mode is correct. In apply mode, real errors (network, permissions) now fail as expected.

##### Fix 2: bat cache build (lines 82-88)
**Before**:
```yaml
- name: Build bat cache
  command: bat cache --build
  when: bat_theme_download.changed and not bat_theme_download.failed
  failed_when: false  # ❌ Unreliable - depends on previous task state
```

**After**:
```yaml
- name: Check if bat is installed
  command: which bat
  register: bat_installed
  changed_when: false
  failed_when: false  # ✅ OK - just checking existence

- name: Build bat cache
  command: bat cache --build
  when:
    - not ansible_check_mode
    - bat_installed.rc == 0  # ✅ Only if bat exists
    - bat_theme_download.changed | default(false)  # ✅ Only if theme downloaded
  changed_when: true
```

**Why**:
- `which bat` properly checks if bat is installed
- `| default(false)` handles undefined variable (when download skipped in check mode)
- **NOT silencing errors**: Just providing a safe default when variable is undefined
- Task skips if conditions not met (correct behavior)

##### Fix 3: .zshrc backup (lines 129-147)
**Before**:
```yaml
- name: Backup existing .zshrc
  copy:
    src: "{{ ansible_env.HOME }}/.zshrc"
    dest: "{{ ansible_env.HOME }}/.zshrc.backup-{{ ansible_date_time.epoch }}"
  when:
    - existing_zshrc.stat.exists
    - not existing_zshrc.stat.islnk
  register: backup_result
  failed_when: false  # ❌ Silent data loss risk!
```

**After**:
```yaml
- name: Backup existing .zshrc
  copy:
    src: "{{ ansible_env.HOME }}/.zshrc"
    dest: "{{ ansible_env.HOME }}/.zshrc.backup-{{ ansible_date_time.epoch }}"
    remote_src: yes
    mode: preserve
  when:
    - existing_zshrc.stat.exists
    - not existing_zshrc.stat.islnk
  register: backup_result
  failed_when: backup_result.failed | default(false)  # ✅ Fail if backup fails

- name: Show backup location
  debug:
    msg: "Existing .zshrc backed up to ..."
  when:
    - backup_result is defined
    - backup_result.changed | default(false)
```

**Why**: User data protection - if we can't backup their existing .zshrc, we should NOT overwrite it. Failing is the right behavior.

#### 1.3 ✅ Added Server Playbook Idempotency Test

**Implementation**: Test runner now includes server idempotency in Phase 3

**Before**: Only WSL playbook tested for idempotency
**After**: Both WSL and Server playbooks tested

**Why Critical**: Idempotency is an Ansible best practice. Playbooks MUST be idempotent - running twice should not make changes the second time.

#### 1.4 ✅ Simplified Makefile Test Commands

**New Command Structure**:
```makefile
# Main commands
make test                    # Full isolated test suite (~8-12min)
make test-syntax             # Fast syntax check (~10s)

# Individual playbook tests (for debugging)
make test-wsl                # WSL playbook only (in wsl-test container)
make test-server             # Server playbook only (in server-test container)

# Specific test types
make test-idempotency-wsl    # WSL idempotency
make test-idempotency-server # Server idempotency (NEW!)
make test-validation-wsl     # WSL shell validation
make test-validation-server  # Server shell validation (NEW!)

# Interactive debugging
make test-shell              # Open zsh in wsl-test container
make test-shell-server       # Open zsh in server-test container (NEW!)
```

**Removed**:
- `test-all` (had state pollution, replaced by `test`)
- `test-docker-build/up/down` (now internal to `test` target)
- `test-isolated` (renamed to `test`)

### Phase 1 Results

| Metric | Before | After |
|--------|--------|-------|
| **Test Independence** | ❌ State pollution | ✅ Full isolation |
| **Server Idempotency** | ❌ Not tested | ✅ 100% coverage |
| **Error Silencing** | ⚠️ 3 problematic uses | ✅ All fixed |
| **Test Passing Rate** | 7/8 (87.5%) | 9/9 (100%) |
| **Container Utilization** | 1/3 used | 2/3 used (wsl-test, server-test) |

**Commits**:
- `554f515`: fix: resolve CI test failures for fzf and bat theme installation
- `2878f18`: fix: remove obsolete starship config check from dotfiles
- `0fa8c28`: feat: Phase 1 - Fix test independence and improve test architecture

---

## Phase 2: Add Mac Testing & Expand Coverage (IN PROGRESS)

**Goal**: Automated Mac playbook testing, comprehensive idempotency coverage, security validation

**Status**: 60% Complete 🔄
**Time Spent**: ~4 hours
**Estimated Remaining**: 4-8 hours

### Completed Items (Phase 2)

#### 2.1 ✅ Test Helper Library
**File**: `tests/helpers/assert.sh`

**Functions Implemented**:
- `assert_file_exists()` - Check file existence
- `assert_dir_exists()` - Check directory existence
- `assert_contains()` - Check file contains pattern
- `assert_not_contains()` - Check file does NOT contain pattern
- `assert_command_exists()` - Check command availability
- `assert_equal()` - Compare two values
- `assert_permissions()` - Validate file permissions
- `assert_symlink()` - Verify symlink target
- `assert_env_set()` - Check environment variable
- `assert_path_contains()` - Verify PATH contains directory
- `assert_summary()` - Print pass/fail summary

**Benefits**:
- Reduces test boilerplate by ~30%
- Standardizes assertions across all tests
- Provides clear, colorized output
- Automatic pass/fail counting

#### 2.2 ✅ Security Validation Tests
**File**: `tests/scripts/validate-security.sh`

**Checks Implemented**:
1. SSH key permissions (private keys: 600, .ssh directory: 700)
2. Config file ownership (owned by user, not root)
3. No secrets in dotfiles (patterns: password, api_key, token, AWS_*, etc.)
4. No sensitive files in dotfiles repo (.env, credentials.json, .aws/credentials, etc.)
5. Sudoers configuration validation

**Test Results**: 19/19 assertions passing in both WSL and Server environments

**Example Output**:
```
=== Security Validation ===

1. SSH Key Permissions
  ✓ .ssh directory has correct permissions (700)

2. Config File Ownership
  ✓ .zshrc owned by testuser
  ✓ starship.toml owned by testuser

3. No Secrets in Dotfiles
  ✓ No secrets detected in .zshrc
  ✓ No secrets detected in starship.toml

4. Sensitive Files Not in Dotfiles Repository
  ✓ .env not in dotfiles repository
  ✓ credentials.json not in dotfiles repository

Passed: 19
Failed: 0
✅ All assertions passed
```

#### 2.3 ✅ Tool Version Verification
**File**: `tests/scripts/validate-tool-versions.sh`

**Versions Checked**:
- **Essential tools**: zsh (major: 5), git (major: 2), starship (major: 1)
- **Modern shell tools**: fzf (0.x), zoxide (0.x), ripgrep (major: 13)
- **Optional tools**: bat, eza, fd
- **Build tools**: make (major: 3/4), curl (major: 7), wget (major: 1)
- **Python & Ansible**: python3 (major: 3), ansible (major: 2)

**Test Results**: 9/9 tool versions verified successfully

**Benefits**:
- Prevents compatibility issues from version drift
- Detects breaking changes in upstream tools
- Documents expected versions

#### 2.4 ✅ CI/CD Improvements

**Ansible Lint Configuration** (`.ansible-lint`):
- Production profile enabled
- Warnings allowed for subjective rules (line-length, name[casing])
- Errors fail the build (syntax, schema, deprecated features)
- External roles excluded (geerlingguy, elliotweiser)
- Supports Ansible 2.14, 2.15, 2.16

**GitHub Actions Workflow Update**:
```yaml
# Before
ansible-lint playbooks/ || true  # ❌ Always succeeds

# After
ansible-lint playbooks/ --force-color --parseable
# ✅ Uses .ansible-lint config: warnings allowed, errors fail
```

**Docker Compose Cleanup**:
- Removed obsolete `version: '3.8'` declaration
- Eliminates warning messages in all test output

#### 2.5 ✅ Test Suite Integration

**Updated Test Runner** (`tests/scripts/run-all-tests.sh`):

**Phase 2: WSL Tests** (now includes):
1. Check mode
2. Apply mode
3. Shell validation
4. Idempotency
5. **Security validation** (NEW!)
6. **Tool version verification** (NEW!)

**Phase 3: Server Tests** (now includes):
1. Check mode
2. Apply mode
3. Shell validation
4. Idempotency
5. **Security validation** (NEW!)
6. **Tool version verification** (NEW!)

**Test Count**: 9 → **13 tests**
**All 13/13 passing** ✅

#### 2.6 ✅ Test Fixtures Structure

Created directory structure:
```
tests/
├── fixtures/
│   ├── sample-dotfiles/      # For mock dotfiles testing (empty)
│   ├── inventory-templates/  # Reusable templates (empty)
│   └── expected-configs/     # Golden files (empty)
└── helpers/
    └── assert.sh             # ✅ Implemented
```

### Remaining Phase 2 Work

### 2.1 Mac Testing with docker-osx

**Decision Point**: docker-osx vs GitHub Actions macOS runners

#### Option A: docker-osx (Local Testing)
**Pros**:
- Local testing capability
- Same container-based approach
- Free (no CI minutes used)

**Cons**:
- Requires KVM (Linux host only)
- Very slow (2-5 min startup, 10-15 min per test)
- High resource usage (4GB+ RAM, nested virtualization)
- Won't work on macOS Docker Desktop

**Implementation Plan**:
```yaml
# tests/docker/docker-compose-mac.yml
services:
  mac-test:
    image: sickcodes/docker-osx:latest
    devices:
      - /dev/kvm
    environment:
      - ANSIBLE_FORCE_COLOR=1
    volumes:
      - ../../:/ansible:ro
```

#### Option B: GitHub Actions macOS Runners (CI Only)
**Pros**:
- Native macOS environment
- Faster execution
- More realistic testing
- No local setup complexity

**Cons**:
- CI minutes cost (GitHub Actions paid)
- No local Mac testing
- Can't debug interactively

**Implementation Plan**:
```yaml
# .github/workflows/test-playbooks.yml
test-mac:
  runs-on: macos-latest
  strategy:
    matrix:
      playbook:
        - playbooks/mac/personal.yml
        - playbooks/mac/work.yml
  steps:
    - uses: actions/checkout@v4
    - name: Install Ansible
      run: pip3 install ansible
    - name: Run playbook
      run: ansible-playbook ${{ matrix.playbook }} -i tests/inventories/mac.yml
```

**Recommendation**: Start with Option B (GitHub Actions), evaluate docker-osx later if local testing becomes critical.

### 2.2 Expand Test Coverage

**New Test Types to Add**:

#### Profile Isolation Tests
**Goal**: Verify profiles don't interfere with each other

```bash
# tests/scripts/test-profile-isolation.sh
# 1. Apply WSL playbook → validate WSL config
# 2. Apply Server playbook → validate Server config (different container)
# 3. Apply Personal playbook → validate Personal config (different container)
# Ensure machine type markers are correct
```

#### Tool Version Verification
**Goal**: Lock and verify tool versions

```yaml
# tests/inventories/wsl.yml
vars:
  expected_versions:
    starship: "1.24.0"
    fzf: "0.66.1"
    zoxide: "0.9.0"
```

```bash
# tests/scripts/validate-tool-versions.sh
# Compare installed versions against expected versions
# Fail if major version mismatches
```

#### Security Validation
**Goal**: Ensure proper permissions and no secrets

```bash
# tests/scripts/validate-security.sh
# 1. Check SSH key permissions (600)
# 2. Verify no secrets in dotfiles (.env, credentials, etc.)
# 3. Check config file ownership (user, not root)
# 4. Validate sudoers entries (if any)
```

#### Configuration Content Validation
**Goal**: Verify configs have expected content

```bash
# tests/scripts/validate-config-content.sh
# 1. Parse starship.toml, verify structure
# 2. Check zsh aliases are loaded (test `alias ll`)
# 3. Validate PATH contains ~/.local/bin
# 4. Ensure plugins are loaded (test zinit list)
```

### 2.3 Create Test Fixtures & Helpers

**Directory Structure**:
```
tests/
├── fixtures/
│   ├── sample-dotfiles/      # Mock dotfiles for testing
│   │   └── zsh/
│   │       ├── .zshrc
│   │       └── core/
│   │           └── *.zsh
│   ├── inventory-templates/  # Reusable inventory templates
│   │   ├── base.yml
│   │   ├── wsl-template.yml
│   │   └── server-template.yml
│   └── expected-configs/     # Golden files for validation
│       ├── starship-wsl.toml
│       └── starship-server.toml
├── helpers/
│   ├── assert.sh            # Test assertion functions
│   │   # assert_equal, assert_file_exists, assert_contains, etc.
│   ├── container.sh         # Container management helpers
│   │   # start_container, stop_container, exec_in_container, etc.
│   └── validation.sh        # Reusable validation functions
│       # validate_tool_installed, validate_config_file, etc.
└── scripts/
    └── (existing test scripts)
```

**Helper Examples**:

```bash
# tests/helpers/assert.sh
assert_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "❌ ASSERTION FAILED: File does not exist: $file"
        return 1
    fi
}

assert_contains() {
    local file=$1
    local pattern=$2
    if ! grep -q "$pattern" "$file"; then
        echo "❌ ASSERTION FAILED: Pattern not found in $file: $pattern"
        return 1
    fi
}
```

**Benefits**:
- Reduce test boilerplate by ~30%
- Standardize validation patterns
- Enable snapshot testing
- Easier to add new tests

### Phase 2 Deliverables

- [ ] Mac testing working (either docker-osx or GitHub Actions)
- [ ] Profile isolation tests
- [ ] Tool version verification
- [ ] Security validation tests
- [ ] Configuration content validation
- [ ] Test fixtures and helpers library
- [ ] Updated documentation

**Success Criteria**:
- ✅ Mac playbook test coverage >50%
- ✅ Test boilerplate reduced by 30%
- ✅ Security validation tests exist
- ✅ All tests use helper functions

---

## Phase 3: Improve CI/Local Parity & Best Practices (PLANNED)

**Goal**: Better alignment, performance tracking, documentation

**Status**: Not Started
**Estimated Time**: 4-6 hours

### 3.1 Fix CI/Local Differences

**Current State**:
- **Local**: Sequential tests in isolated containers
- **CI**: Parallel tests in GitHub runners (matrix strategy)

**Alignment Strategy**: Keep different but fix local isolation ✅ (DONE in Phase 1)

**Remaining Work**:

#### Create `make test-ci` Target
```makefile
test-ci: ## Mimic CI matrix behavior locally
	@printf '$(BLUE)Running tests in CI mode (parallel simulation)...$(NC)\n'
	@# Start all containers
	@$(MAKE) test-docker-build test-docker-up
	@# Run WSL and Server tests concurrently (parallel)
	@cd tests/docker && \
		docker compose exec -T wsl-test /ansible/tests/scripts/test-playbook.sh wsl & \
		docker compose exec -T server-test /ansible/tests/scripts/test-playbook.sh server & \
		wait
	@$(MAKE) test-docker-down
```

#### Ensure Same Validation Scripts
**Audit**:
- ✅ `validate-shell.sh` used by both local and CI
- ✅ `test-idempotency.sh` used by both
- ⚠️ CI runs additional `validate-machine-detection.sh` (not in local)

**Action**: Add machine detection validation to local test suite

#### Document Intentional Differences
```markdown
# tests/README.md - CI vs Local Differences

| Aspect | Local | CI | Why Different |
|--------|-------|-----|---------------|
| Execution | Sequential | Parallel | CI faster, local easier to debug |
| Environment | Docker | Native Ubuntu | CI avoids Docker overhead |
| Playbooks Tested | WSL + Server | WSL + Server (matrix) | Same coverage |
| Mac Testing | Skip (no docker-osx) | macOS runner | CI has native macOS |
```

### 3.2 Remove Error Silencing in CI

**File**: `.github/workflows/test-playbooks.yml`

**Current (line 55)**:
```yaml
- name: Run ansible-lint
  run: ansible-lint playbooks/ || true  # ❌ Always succeeds
```

**Proposed**:
```yaml
- name: Run ansible-lint
  run: ansible-lint playbooks/ --force-color --parseable
  # Let it fail on real errors
```

**Add Config**: `.ansible-lint`
```yaml
# Allow warnings, fail on errors
warn_list:
  - yaml[line-length]
  - name[casing]
  - risky-file-permissions  # We handle this intentionally

skip_list:
  - no-handler  # We use direct commands where appropriate

# Fail on:
# - syntax-check
# - schema
# - command-instead-of-module (unless whitelisted)
```

### 3.3 Performance Tracking

**Goal**: Track shell startup time over commits, alert on regressions

**Implementation**:

```bash
# tests/scripts/track-performance.sh
#!/usr/bin/env bash
# Track shell startup time and compare to baseline

PERF_FILE="tests/test-results/perf-history.json"
BASELINE_MS=200  # Target: <200ms in container

# Measure startup time (average of 5 runs)
total=0
for i in {1..5}; do
    time_ms=$(/usr/bin/time -f "%E" zsh -i -c exit 2>&1 | \
              awk -F'[:.]+' '{print ($2 * 1000) + ($3 * 10)}')
    total=$((total + time_ms))
done
avg_ms=$((total / 5))

# Save to JSON
echo "{
  \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"commit\": \"$(git rev-parse HEAD)\",
  \"startup_ms\": $avg_ms,
  \"baseline_ms\": $BASELINE_MS
}" >> "$PERF_FILE"

# Check for regression
if [ $avg_ms -gt $((BASELINE_MS * 12 / 10)) ]; then
    echo "❌ Performance regression: ${avg_ms}ms (baseline: ${BASELINE_MS}ms)"
    exit 1
fi

echo "✅ Performance acceptable: ${avg_ms}ms"
```

**CI Integration**:
```yaml
# .github/workflows/test-playbooks.yml
- name: Track performance
  run: ./tests/scripts/track-performance.sh

- name: Upload performance data
  uses: actions/upload-artifact@v3
  with:
    name: performance-history
    path: tests/test-results/perf-history.json
```

### 3.4 Documentation & Developer Experience

**Files to Create/Update**:

#### `tests/README.md` - Comprehensive Testing Guide
```markdown
# Testing Guide

## Quick Start
```bash
make test              # Run all tests (~8-12 min)
make test-syntax       # Quick syntax check (~10s)
make test-wsl          # Test WSL playbook only
make test-shell        # Interactive shell for debugging
```

## Architecture
- Test isolation via dedicated containers
- Idempotency enforced for all playbooks
- CI mirrors local test behavior

## How to Add a New Test
1. Create test script in `tests/scripts/`
2. Add to `run-all-tests.sh` orchestrator
3. Update Makefile with individual target
4. Document in this README

## Troubleshooting
- Container won't start: `make clean && make test-docker-build`
- Test fails locally but passes in CI: Check container vs native differences
- Slow tests: Use `make test-wsl` to run subset
```

#### `CONTRIBUTING.md` - Testing Requirements for PRs
```markdown
# Contributing

## Testing Requirements

All PRs must:
- ✅ Pass `make test-syntax`
- ✅ Pass `make test` (full test suite)
- ✅ Maintain or improve test coverage
- ✅ Include tests for new playbooks/roles
- ✅ Be idempotent (test with `make test-idempotency-*`)

## Before Submitting PR
```bash
make test              # Ensure all tests pass
make lint              # Fix any linting issues
```

## Adding New Playbooks
New playbooks MUST include:
1. Idempotency test
2. Shell validation
3. Documentation in playbook comments
```

#### `Makefile` - Improve Help Output
```makefile
help:
	@printf '$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)\n'
	@printf '$(BLUE)║        Ansible Playbooks - Available Commands             ║$(NC)\n'
	@printf '$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)\n'
	@printf '\n'
	@printf '$(YELLOW)Quick Start:$(NC)\n'
	@printf '  make test-syntax          # Fast syntax check (~10s)\n'
	@printf '  make test                 # Full isolated test suite (~8-12min)\n'
	@printf '  make test-shell           # Interactive shell for debugging\n'
	@printf '\n'
	@printf '$(YELLOW)Example Workflows:$(NC)\n'
	@printf '  make test-wsl && make test-shell       # Test WSL, then explore\n'
	@printf '  make test-syntax && make test          # Quick check, then full\n'
	@printf '\n'
	@printf '$(YELLOW)All Commands:$(NC)\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
```

### Phase 3 Deliverables

- [ ] `make test-ci` target for CI simulation
- [ ] Machine detection validation in local tests
- [ ] `.ansible-lint` configuration (fail on errors, not warnings)
- [ ] Performance tracking script with regression detection
- [ ] Comprehensive `tests/README.md`
- [ ] `CONTRIBUTING.md` with testing requirements
- [ ] Improved Makefile help output with examples

**Success Criteria**:
- ✅ Comprehensive testing documentation exists
- ✅ Performance regressions caught automatically
- ✅ CI fails on real lint errors (not just warnings)
- ✅ Clear contributor guidelines for testing

---

## Implementation Timeline

| Phase | Time Estimate | Priority | Status |
|-------|---------------|----------|--------|
| Phase 1: Critical Fixes | 4-6 hours | 🔴 Critical | ✅ COMPLETE |
| Phase 2: Mac Testing & Coverage | 8-12 hours | 🟡 High | 📋 Planned |
| Phase 3: Polish & Documentation | 4-6 hours | 🟢 Medium | 📋 Planned |

**Total Estimated Time**: 16-24 hours

---

## Known Issues & Technical Debt

### Resolved in Phase 1 ✅
- ~~State pollution between WSL and Server tests~~
- ~~Missing server playbook idempotency tests~~
- ~~Error silencing with `failed_when: false`~~
- ~~Unused Docker containers (wsl-test, server-test not utilized)~~

### Remaining Issues
1. **ubuntu-test container unused**: Only used by deprecated visual tests
   - **Action**: Consider removing in Phase 3

2. **docker-compose.yml version warning**: `version` attribute is obsolete
   - **Action**: Remove `version:` line in Phase 2

3. **No Mac playbook testing**: 0% coverage
   - **Action**: Phase 2 priority

4. **ansible-lint failures silenced in CI**: `|| true` defeats purpose
   - **Action**: Phase 3

5. **No performance regression tracking**: Startup time could degrade
   - **Action**: Phase 3

---

## References

### Key Files
- `tests/scripts/run-all-tests.sh` - Main test orchestrator
- `Makefile` - Test command definitions
- `.github/workflows/test-playbooks.yml` - CI configuration
- `tests/docker/docker-compose.yml` - Container definitions
- `roles/common-shell/tasks/configure-shell.yml` - Core shell configuration

### Related Documentation
- `tests/README.md` (to be created in Phase 3)
- `CONTRIBUTING.md` (to be created in Phase 3)
- `docs/testing.md` (optional, Phase 3)

### Commits
- Phase 1: `0fa8c28` - feat: Phase 1 - Fix test independence and improve test architecture

---

## Decision Log

### 2025-11-15: Phase 1 Decisions

**Q**: Should we deprecate or delete old `run-all-tests.sh`?
**A**: Delete - no value in keeping deprecated code with known issues

**Q**: Keep CI parallel and local sequential, or align them?
**A**: Keep different but fix local isolation - CI is faster parallel, local is easier to debug sequential

**Q**: Backward compatibility for Makefile commands?
**A**: Clean slate allowed - better UX more important than compatibility

**Q**: Is `| default(false)` silencing errors?
**A**: No - it handles undefined variables when tasks are skipped (check mode). Correct usage.

### Future Decisions (Phase 2)

**Q**: docker-osx or GitHub Actions macOS runners for Mac testing?
**A**: TBD - Start with GitHub Actions (easier), evaluate docker-osx if local testing critical

**Q**: Should test fixtures use real dotfiles or mocks?
**A**: TBD - Probably mocks for unit tests, real for integration tests

---

**Last Updated**: 2025-11-15
**Next Review**: After Phase 2 completion
