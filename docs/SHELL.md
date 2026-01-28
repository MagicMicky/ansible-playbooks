# Shell Philosophy & Design

This document explains the design decisions, tool choices, and visual language of our shell configuration.

## Core Philosophy

**Goal**: A fast, consistent, visually informative shell across all machines - from personal laptops to production servers.

**Principles**:
- **Speed**: Shell startup under 100ms (workstations) / 50ms (servers)
- **Consistency**: Same tools and patterns everywhere
- **Context awareness**: Prompt tells you where you are and what state you're in
- **DRY**: One configuration, multiple deployments via Ansible

## Why These Tools

### Zinit over Oh-My-Zsh

| Aspect | Oh-My-Zsh | Zinit |
|--------|-----------|-------|
| Startup time | ~200-400ms | ~50-80ms |
| Plugin loading | Synchronous | Async (turbo mode) |
| Flexibility | Framework-bound | Modular |

Zinit provides 3-4x faster startup through lazy loading and turbo mode. Plugins load asynchronously after the prompt appears.

### Starship Prompt

- **Cross-shell**: Works with zsh, bash, fish - same config everywhere
- **Rust-based**: Fast rendering, no shell overhead
- **Configurable**: TOML config, easy to template with Ansible
- **Context-aware**: Shows git, languages, k8s, AWS automatically

### Modern CLI Replacements

| Classic | Modern | Why |
|---------|--------|-----|
| `cat` | `bat` | Syntax highlighting, line numbers, git integration |
| `ls` | `eza` | Colors, icons, git status, tree view |
| `find` | `fd` | Faster, simpler syntax, respects .gitignore |
| `grep` | `ripgrep` | 10x faster, respects .gitignore |
| `cd` | `zoxide` | Learns your habits, jump by partial match |
| - | `fzf` | Fuzzy finding for everything |

These tools share a philosophy: sensible defaults, speed, and modern UX.

## Theme: Catppuccin Mocha

We use [Catppuccin Mocha](https://github.com/catppuccin/catppuccin) - a warm, pastel dark theme.

**Why Catppuccin**:
- Consistent palette across tools (terminal, editors, apps)
- Easy on the eyes for long sessions
- Well-maintained with ports for everything
- Semantic color assignments

**Key Colors**:
```
Blue (#89b4fa)     - Primary, personal, info
Cyan (#89dceb)     - Secondary, pro/work
Green (#a6e3a1)    - Success, safe
Yellow (#f9e2af)   - Warning, attention
Red (#f38ba8)      - Error, danger, production
Peach (#fab387)    - Git changes, dev servers
Mauve (#cba6f7)    - Git branches, special
Lavender (#b4befe) - Directories
```

Theme variables are defined in `roles/common-shell/vars/catppuccin-mocha.yml` and used across all templates.

## Visual Indicator System

The prompt character and color instantly tell you what type of machine you're on.

### Prompt Characters

| Character | Meaning | When |
|-----------|---------|------|
| `λ` | Workstation | Laptops, WSL - full development environment |
| `!` | Production | Production servers - be careful! |
| `·` | Server | Dev, gaming, homelab servers |

### Color Meanings

| Color | Hex | Meaning | Usage |
|-------|-----|---------|-------|
| Blue | `#89b4fa` | Personal | Personal laptop, safe environment |
| Cyan | `#89dceb` | Professional | Work laptop, pro profile |
| Red | `#f38ba8` | Danger | Production servers, errors |
| Orange | `#fab387` | Caution | Dev servers, warnings |
| Purple | `#cba6f7` | Special | Gaming servers, git branches |

### Machine Type Matrix

| Profile | Character | Color | Use Case |
|---------|-----------|-------|----------|
| `laptop` | λ | Blue | Personal Mac/Linux |
| `pro` | λ | Cyan | Work laptop |
| `wsl` | λ | Blue | WSL environment |
| `server` (production) | ! | Red | Production servers |
| `server` (dev) | · | Orange | Development servers |
| `server` (gaming) | · | Purple | Gaming servers |
| `server` (homelab) | · | Cyan | Home lab, NAS |

### Server Type Auto-Detection

When `machine_profile=server`, the hostname determines styling:

```
prod-*, production-*  → Production (red !)
dev-*                 → Development (orange ·)
gaming-*              → Gaming (purple ·)
homelab-*, nas-*      → Homelab (cyan ·)
*                     → Generic (cyan ·)
```

This means: name your servers with prefixes and get automatic visual differentiation.

## Prompt Information

### Always Shown
- Current directory (truncated to 4 levels)
- Prompt character with color

### Shown When Relevant
- **Git**: Branch name, status (modified, staged, ahead/behind)
- **SSH**: Username and hostname when connected remotely
- **Error**: Red prompt character on command failure
- **Duration**: Command time if >2 seconds

### Workstation Only (laptop, pro, wsl)
- Python version and virtualenv
- Node.js version
- Go version
- Rust version

### Pro Profile Only
- Kubernetes context and namespace
- AWS profile and region
- Terraform workspace

## Performance Targets

| Environment | Target | Typical | Notes |
|-------------|--------|---------|-------|
| Laptop | <100ms | 50-80ms | Full plugin suite |
| WSL | <100ms | 60-80ms | Full plugin suite |
| Server | <50ms | 30-50ms | Minimal plugins |
| Docker test | <200ms | 100-150ms | Container overhead |

**Measure with**: `time zsh -i -c exit` or `hyperfine 'zsh -i -c exit'`

### Performance Techniques

1. **Zinit turbo mode**: Plugins load async after prompt
2. **Lazy completions**: Heavy completions (kubectl, aws) load on first use
3. **Minimal server profile**: Only essential plugins on servers
4. **No framework overhead**: Zinit vs Oh-My-Zsh saves ~150ms

## Shell Load Order

```
~/.zshrc
  └── Sources all files in ~/.zsh.d/ (alphabetically)
      ├── 01-zinit.zsh      # Plugin manager setup
      ├── 10-path.zsh       # PATH configuration
      ├── 20-env.zsh        # Environment variables, UTF-8 fix
      ├── 25-tools.zsh      # Tool integrations (fzf, zoxide)
      ├── 30-aliases.zsh    # Command aliases
      ├── 40-functions.zsh  # Helper functions
      ├── config.zsh        # Profile-specific config
      ├── overrides.zsh     # Profile-specific overrides
      └── plugins.zsh       # Profile-specific plugins
  └── Starship init
  └── fzf keybindings
  └── zoxide init
```

Numbered files (01-40) are universal. Non-numbered files are profile-specific symlinks created by Ansible.

## Profile System

### laptop (Personal)
- Full tool suite
- All language version indicators
- Blue prompt
- Personal git config

### pro (Work)
- Everything from laptop
- Kubernetes/AWS/Terraform in prompt
- Work-specific aliases
- Cyan prompt to distinguish from personal

### wsl (Windows Subsystem for Linux)
- Full tool suite like laptop
- Windows interop (clip.exe, explorer.exe aliases)
- WSL-specific path handling
- Blue prompt

### server (Remote Servers)
- Minimal plugin set for speed
- No language indicators (not needed)
- Auto-detection of server type from hostname
- Color-coded by server purpose

## Key Files

### Ansible Templates
- `roles/common-shell/templates/starship.toml.j2` - Prompt configuration
- `roles/common-shell/templates/shell-theme.zsh.j2` - Theme variables
- `roles/common-shell/vars/catppuccin-mocha.yml` - Color definitions

### Dotfiles (symlinked by Ansible)
- `zsh/core/01-zinit.zsh` - Plugin manager
- `zsh/core/20-env.zsh` - Environment setup (includes UTF-8 fix)
- `zsh/core/30-aliases.zsh` - Universal aliases
- `zsh/profiles/*/` - Profile-specific configurations

## Known Issues & Fixes

### Tab Completion Character Duplication
**Issue**: Starship caused character duplication during tab completion
**Cause**: Invalid UTF-8 locale during Starship initialization
**Fix**: `zsh/core/20-env.zsh` sets UTF-8 locale with C.UTF-8 fallback
**Reference**: https://github.com/starship/starship/issues/2176

## Resources

- [Zinit Documentation](https://github.com/zdharma-continuum/zinit)
- [Starship Configuration](https://starship.rs/config/)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)
- [fzf Documentation](https://github.com/junegunn/fzf)
- [zoxide Documentation](https://github.com/ajeetdsouza/zoxide)
