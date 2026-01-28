# CLAUDE.md

Guidance for Claude Code when working in the ansible-playbooks repository.

## BEFORE MAKING ANY CHANGES

Before editing, writing, or deleting any file, you MUST:

1. **Check your branch** - Are you on a feature branch?
   ```bash
   git branch --show-current
   ```
   If on `main` or wrong branch:
   ```bash
   git checkout main && git pull origin main
   git checkout -b claude/<brief-description>
   ```

2. **After making changes** - Complete the FULL workflow:
   - `make test-syntax` (fast sanity check)
   - `git add <specific-files>` + `git commit -m "type: description"`
   - `git push -u origin <branch>`
   - `gh pr create` (if PR doesn't exist) - **provide PR URL to user**
   - Use `ci-monitor` agent to track CI

3. **Do NOT stop early** - Task is incomplete until PR exists and CI is monitored

**This applies when user asks to:** fix, update, change, remove, add, refactor, clean up, or modify anything.

See [Git Workflow](#git-workflow) for detailed steps and commit conventions.

---

## Project Overview

Ansible automation for shell configuration and system setup across multiple machine types. Deploys a modern shell stack (Zinit, Starship, fzf, zoxide) with DRY principles.

**This repository is PUBLIC** - never commit passwords, API keys, SSH keys, or sensitive data.

## Playbooks & Targets

| Playbook | Target | Profile | Command |
|----------|--------|---------|---------|
| `playbooks/mac/personal.yml` | Personal Mac | `laptop` | `make mac-personal` |
| `playbooks/mac/work.yml` | Work Mac | `pro` | `make mac-work` |
| `playbooks/wsl/setup.yml` | WSL/Ubuntu | `wsl` | `make wsl` |
| `playbooks/servers/setup.yml` | Linux servers | `server` | `make server INVENTORY=...` |

Each playbook has a corresponding `vars/` directory for platform-specific variables.

## Directory Structure

```
playbooks/           # Platform-specific playbooks
  mac/personal.yml   # Personal Mac (full shell + apps)
  mac/work.yml       # Work Mac (personal + work tools)
  wsl/setup.yml      # WSL environment
  servers/setup.yml  # Remote servers (minimal)

roles/               # Reusable Ansible roles
  common-shell/      # Core shell setup (zinit, starship, modern tools)
  mac-system/        # macOS preferences, fonts
  app-config/        # Application configs (git, vim, etc.)

tests/               # Docker-based testing infrastructure
  docker/            # Compose files, Dockerfiles
  scripts/           # Validation scripts
  inventories/       # Test inventory files

docs/                # Documentation (keep up to date!)
  ARCHITECTURE.md    # Design principles, data flow
  PLAYBOOKS.md       # Playbook usage reference
  ROLES.md           # Role documentation

inventories/         # Production inventory files
```

## Common Commands

### Testing

```bash
# Always run before pushing (fast ~10s, no Docker)
make test-syntax

# Docker tests - only when debugging CI failures or complex changes
make test-wsl              # Apply WSL playbook in container
make test-server           # Apply server playbook in container
make test                  # Full test suite (slow)

# Interactive debugging
make test-shell            # Open zsh in WSL container
make test-visual           # Apply playbook + open shell
```

### Deployment (Real Machines)

**DO NOT run deployment commands** - these modify the user's actual machine and are blocked in `.claude/settings.json`:
- `make mac-personal`, `make mac-work`, `make wsl`, `make server`
- `ansible-playbook ... -i inventories/localhost`

The user runs these manually when ready.

### Other

```bash
make help                  # Show all commands
make lint                  # Run ansible-lint
make deps                  # Install Galaxy dependencies
make clean                 # Stop containers, clean artifacts
```

## CI/CD

GitHub Actions workflow defined in `.github/workflows/test-playbooks.yml`. Read that file to understand the current jobs and triggers.

CI runs automatically on PRs. **All tests must pass before merging.**

### CI Monitoring

After pushing changes or creating a PR, **use the `ci-monitor` agent** to track the run:

```
Use the ci-monitor agent to check CI for branch <branch-name>
```

The agent (defined in `.claude/agents/ci-monitor.md`) will:
1. Find the latest run for the branch
2. Wait for completion (polling every 30s)
3. Analyze results and get logs if failed
4. Report back with status and suggested fixes

Run it in background for long CI runs. It uses `sonnet` for reasoning depth when debugging failures.

**Quick CI commands** (for manual checks):
```bash
gh run list --limit 5                    # Recent runs
gh run view <RUN_ID> --verbose           # Job details
gh run view <RUN_ID> --log-failed        # Failed step logs
gh run watch <RUN_ID>                    # Wait for completion
```

## Git Workflow

### Branch Strategy
- **New features**: Create branch from main with format `claude/<brief-description>`
- **Small fixes**: Can be committed to an existing feature branch
- **Never commit directly to `main`**

### Commit → Push → PR → CI Workflow

1. **Branch** - For new features, start from main
   ```bash
   git checkout main && git pull origin main
   git checkout -b claude/<description>
   ```

2. **Commit** - Make small, focused commits
   - Use conventional commits: `fix:`, `feat:`, `docs:`, `refactor:`, `test:`, `chore:`
   - Run `make test-syntax` before committing
   ```bash
   git add <specific-files>
   git commit -m "feat: add validation for backup paths"
   ```

3. **Push** - Push to remote
   ```bash
   git push -u origin claude/<description>
   ```

4. **Create PR** - REQUIRED after every push (if PR doesn't exist)
   ```bash
   gh pr create --title "feat: description" --body "Summary of changes"
   ```
   - Provide the PR URL to the user

5. **Monitor CI** - REQUIRED after creating/updating PR
   - Use the `ci-monitor` agent to track the CI run
   - Fix CI failures promptly

## Documentation

Documentation lives in `docs/`:
- `SHELL.md` - **Shell philosophy**: tool choices, theme, visual indicators, performance targets
- `ARCHITECTURE.md` - System design, principles
- `PLAYBOOKS.md` - How to use each playbook
- `ROLES.md` - Role reference and variables

**Keep docs updated** when making changes:
- New role/playbook? Update relevant doc
- Changed variables? Update ROLES.md
- New feature? Document in appropriate file

## Key Roles

### `common-shell`
The main role - installs and configures:
- Zinit (plugin manager)
- Starship prompt (via `templates/starship.toml.j2`)
- Modern tools: fzf, zoxide, bat, eza, fd, ripgrep
- Dotfiles symlinks in `~/.zsh.d/`

Templates are in `roles/common-shell/templates/`. See `docs/SHELL.md` for design philosophy, theme details, and visual indicator meanings.

### `mac-system`
macOS-only: Dock settings, Finder preferences, fonts.

### `app-config`
Application configs: git, vim, Claude settings.

## Testing Philosophy

**Default workflow**: `make test-syntax` → push → let CI validate

- `make test-syntax` is fast (~10s) - always run before pushing
- Full Docker tests (`make test-wsl`, `make test`) are slow - let CI handle them
- **Idempotency**: Playbooks should produce no changes on second run

**When to use Docker tests locally**:
- CI fails repeatedly and you need to debug
- Making complex changes where quick iteration helps
- Investigating shell behavior interactively (`make test-shell`)

Don't burn time running full Docker tests for simple syntax/config changes.

## Security Reminders

This is a **PUBLIC repository**:
- No passwords or secrets in any file
- No SSH private keys
- No API tokens
- Use `ansible-vault` for any sensitive data (though prefer keeping secrets out entirely)
- Server inventories with real IPs should use `servers-example.yml` as template, not committed real files

## Related Repositories

Changes often span multiple repos. Understand the dependencies.

### dotfiles
**Shell configuration files** - zsh, git, vim configs. Separate git repository.

- **Branch**: `master` is the default. Override with `dotfiles_branch` variable if needed.
- **Integration**:
  - `common-shell` role clones this repo and symlinks zsh files to `~/.zsh.d/`
  - `app-config` role symlinks git config, claude settings, etc.
- **Repo URL**: Configured via `dotfiles_repo_url` variable in playbooks

**Workflow when changing shell config**:
1. Edit files in dotfiles repo (`zsh/core/`, `zsh/profiles/`)
2. Commit and **push to dotfiles repo first**
3. Then run ansible-playbook (which pulls the dotfiles)

Structure:
```
dotfiles/zsh/
├── core/           # Universal (01-zinit, 20-env, 30-aliases, etc.)
└── profiles/       # Machine-specific (laptop/, pro/, server/, wsl/)
```

### infra
**Infrastructure-as-Code** - Packer images, Terraform, server provisioning. Separate git repository.

- **Integration**: infra's CI/CD pipeline uses ansible-playbooks for base image builds
- **How**: infra imports `playbooks/servers/setup.yml` for server shell setup
- **CI**: GitHub Actions checks out ansible-playbooks with deploy key

When changing server shell config, infra's base images will pick up changes on next build.

### mac-playbook-work (private)
**Work-sensitive configs** - VPN, work repos, credentials. Separate private repository.

- Kept separate from public repos for security
- Called by `playbooks/mac/work.yml`
- Non-sensitive work helpers go in `dotfiles/zsh/profiles/pro/` instead

## Common Gotchas

### Forgetting to push dotfiles
**Symptom**: Playbook runs but shell changes don't appear.
**Cause**: ansible-playbooks clones dotfiles from git - local uncommitted changes aren't seen.
**Fix**: Always commit and push dotfiles changes before running playbooks.

### Branch mismatch
**Symptom**: Wrong version of shell config deployed.
**Cause**: `dotfiles_branch` variable doesn't match your working branch.
**Fix**: Set `dotfiles_branch` in playbook vars or pass via `-e dotfiles_branch=<branch>`.

### Editing wrong repo
**Symptom**: Shell config changes don't persist.
**Cause**: Edited files in `~/.zsh.d/` (symlinks) instead of source in `dotfiles/`.
**Fix**: Always edit in `dotfiles/` repo, then run playbook to deploy.

## Troubleshooting

### Container issues
```bash
make clean                 # Reset everything
make test-docker-build     # Rebuild containers
```

### Shell not working in container
```bash
make test-shell            # Debug interactively
# Check: ls ~/.zsh.d/, starship --version, echo $MACHINE_TYPE
```

### CI failures
```bash
gh pr checks               # See which job failed
gh run view                # Detailed logs
```

## Resources

- Shell philosophy & design: `docs/SHELL.md`
- CI monitor agent: `.claude/agents/ci-monitor.md`
- Testing guide: `tests/README.md`
- Starship: https://starship.rs/config/
- Zinit: https://github.com/zdharma-continuum/zinit
- Ansible docs: https://docs.ansible.com/
