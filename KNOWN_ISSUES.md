# Known Issues

**Purpose**: Track known issues, limitations, and workarounds for the ansible-playbooks repository.

**Last Updated**: 2025-11-13

---

## Active Issues

### No active issues currently

The consolidation has been validated and all playbooks passed syntax checks. Issues will be documented here as they are discovered during testing and deployment.

---

## Platform-Specific Considerations

### macOS

#### Homebrew Installation
**Issue**: Homebrew may prompt for password during installation
**Impact**: Playbook may hang waiting for user input
**Workaround**: Run playbook with `-K` flag to prompt for sudo password upfront
```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
```

#### macOS System Preferences
**Issue**: Some macOS preferences require logout/restart to take effect
**Impact**: Not all settings apply immediately
**Workaround**: Log out and log back in after playbook completes, or run:
```bash
killall Dock
killall Finder
```

#### macOS Catalina+ Security
**Issue**: macOS may block unsigned binaries installed via Homebrew
**Impact**: Some tools may not run without manual approval
**Workaround**: Go to System Preferences → Security & Privacy → General, click "Allow" for blocked apps

### WSL (Windows Subsystem for Linux)

#### WSL Detection
**Consideration**: Machine type detection relies on `$WSL_DISTRO_NAME` environment variable
**Impact**: Should work automatically in WSL2
**Verification**: Check with `echo $WSL_DISTRO_NAME`

#### Windows Path Integration
**Consideration**: WSL may include Windows paths in `$PATH`
**Impact**: May cause conflicts with Linux binaries
**Note**: Handled in shell configuration, no action needed

### Servers

#### Docker Installation on ARM
**Consideration**: Docker installation may differ on ARM architecture
**Impact**: server-base role may need ARM-specific tasks
**Status**: Not yet tested on ARM servers

#### Minimal Shell on Production
**Consideration**: Production servers use minimal shell configuration
**Impact**: Some tools (bat, eza, fd) are skipped for performance
**Design**: Intentional, production servers prioritize speed

---

## Role-Specific Issues

### common-shell Role

#### Shell Startup Time
**Target**: <100ms for laptops, <50ms for servers
**Status**: Not yet measured (pending deployment)
**Validation**: Test with `time zsh -i -c exit` after deployment

#### Starship Prompt Characters
**Consideration**: Character rendering (λ, !, ·) depends on font support
**Recommendation**: Use Powerline fonts or Nerd Fonts
**Fallback**: Characters should render in most modern terminals

### mac-system Role

#### Font Installation
**Issue**: Powerline fonts installation requires manual font book refresh on some systems
**Impact**: Fonts may not appear immediately in applications
**Workaround**: Restart application or run `sudo atsutil databases -remove`

### app-config Role

#### Sublime Text Package Control
**Consideration**: Package Control installation requires Sublime Text to be running
**Impact**: Plugins may not install on first run
**Workaround**: Open Sublime Text manually to trigger Package Control installation

### server-base Role

#### Docker Compose Version
**Consideration**: Docker Compose V2 (plugin) vs V1 (standalone)
**Status**: Role installs V1 via pip
**Note**: May need update for V2 (docker-compose-plugin)

---

## Integration Issues

### work-tasks Role (mac-playbook-work)

#### External Repository Dependency
**Consideration**: Requires access to private `mac-playbook-work` repository
**Impact**: Work playbook will fail without access
**Expected**: By design, work configs are separate

#### N26-Specific Tools
**Consideration**: Work playbook includes N26 internal tools
**Impact**: Tools may break if N26 infrastructure changes
**Ownership**: Maintained separately in work repository

### infra Integration

#### Backward Compatibility
**Status**: Old tasks commented out in `infra/ansible/ubuntu/base.yml`
**Reason**: Preserved for rollback capability
**Action**: Remove after successful testing validates new approach

---

## Testing Limitations

### macOS Testing in Docker
**Limitation**: Cannot test macOS-specific tasks in Docker
**Impact**: Mac playbooks require testing on actual macOS
**Approach**: Use `--check` mode on real Mac, syntax validation in CI

### Idempotency
**Status**: Not yet validated
**Required**: Run playbooks twice, verify no changes on second run
**Testing**: Pending Phase 8

### Performance Metrics
**Status**: Shell startup time not yet measured
**Required**: Benchmark before/after Prezto → Zinit migration
**Testing**: Pending deployment

---

## Documentation Gaps

### Missing Documentation
- [ ] Docker testing guide implementation (tests/README.md created but containers not built)
- [ ] CI/CD automation setup (CI_CD.md created but workflows not implemented)
- [ ] Deployment log template (planned in NEXT_STEPS.md)

### Documentation Needs Update
None currently. All documentation has been updated to reflect consolidation completion.

---

## Compatibility Matrix

| Platform | Status | Tested | Notes |
|----------|--------|--------|-------|
| macOS 13+ (Ventura) | ✅ Expected | ❌ Pending | Syntax validated |
| macOS 12 (Monterey) | ✅ Expected | ❌ Pending | Syntax validated |
| macOS 11 (Big Sur) | ⚠️ Unknown | ❌ Pending | Should work |
| Ubuntu 22.04 LTS | ✅ Expected | ❌ Pending | Target platform |
| Ubuntu 20.04 LTS | ✅ Expected | ❌ Pending | Should work |
| WSL2 Ubuntu | ✅ Expected | ❌ Pending | Primary test target |
| Debian 11+ | ⚠️ Unknown | ❌ Not tested | May work |

---

## Workarounds and Solutions

### ansible-galaxy Install Failures

**Issue**: `ansible-galaxy install -r requirements.yml` fails to find work-tasks role
**Cause**: Private repository requires authentication
**Solution**:
```bash
# Ensure SSH key is loaded
ssh-add ~/.ssh/id_rsa

# Or use HTTPS with token
git config --global url."https://TOKEN@github.com/".insteadOf "git@github.com:"
```

### Permission Denied Errors

**Issue**: Tasks fail with "Permission denied" on file operations
**Cause**: Insufficient permissions
**Solution**: Run with `-K` flag to prompt for sudo password:
```bash
ansible-playbook playbooks/mac/personal.yml -i inventories/localhost -K
```

### macOS Rosetta Issues (Apple Silicon)

**Issue**: Some Homebrew packages require Rosetta on M1/M2 Macs
**Impact**: First-time installation may trigger Rosetta install
**Solution**: Install Rosetta manually first:
```bash
softwareupdate --install-rosetta --agree-to-license
```

---

## Reporting New Issues

When encountering a new issue:

1. **Document the issue** in this file under "Active Issues"
2. **Include**:
   - Clear description of the problem
   - Platform/environment details
   - Steps to reproduce
   - Error messages (if any)
   - Workaround (if found)
3. **Update** this file with resolution when fixed
4. **Move** to "Resolved Issues" section below when closed

**Template**:
```markdown
#### Issue Title
**Issue**: Brief description
**Platform**: macOS/WSL/Ubuntu/Server
**Impact**: How it affects users
**Cause**: Root cause (if known)
**Workaround**: Temporary solution
**Status**: Open/In Progress/Resolved
```

---

## Resolved Issues

### None Yet

Issues will be moved here once resolved.

**Example format**:
```markdown
#### Example Resolved Issue
**Issue**: Description of the problem
**Resolution**: How it was fixed
**Commit**: abc1234
**Resolved**: 2025-11-13
```

---

## Future Enhancements

These are not issues but improvements to consider:

### Performance Optimizations
- [ ] Implement zinit turbo mode for faster shell startup
- [ ] Profile shell startup time and optimize bottlenecks
- [ ] Cache frequently-used commands

### Feature Additions
- [ ] Add support for fish shell (currently zsh-only)
- [ ] Create Windows-native setup (currently WSL-only)
- [ ] Add optional GUI tools installation (VS Code, etc.)

### Testing Improvements
- [ ] Add molecule tests for all roles
- [ ] Implement automated performance benchmarking
- [ ] Create integration test suite

---

## Support Resources

### Getting Help
- Check `ansible-playbooks/STATUS.md` for current status
- Review `ansible-playbooks/TESTING_CHECKLIST.md` for validation procedures
- See `ansible-playbooks/docs/MIGRATION.md` for migration issues
- Consult `_doc/` planning documents for design decisions

### Debugging
- Run with verbose output: `-vv` or `-vvv`
- Check syntax: `ansible-playbook <playbook> --syntax-check`
- Dry run: `ansible-playbook <playbook> --check`
- Step through: `ansible-playbook <playbook> --step`

---

**Note**: This is a living document. Update it as issues are discovered and resolved during testing and deployment.

**Status**: Initial version created during documentation cleanup
**Next Update**: After Phase 8 testing begins
