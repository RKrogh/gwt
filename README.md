# gwt — Git Worktree Manager

A lightweight CLI tool for managing git worktrees. Built for developers who work on multiple branches simultaneously, especially useful when running parallel AI coding agents (e.g. Claude Code) on separate tasks.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Windows (PowerShell)](#windows-powershell)
  - [Linux / macOS (Bash)](#linux--macos-bash)
- [Commands](#commands)
  - [add](#add)
  - [open](#open)
  - [list](#list)
  - [status](#status)
  - [pull](#pull)
  - [cd](#cd)
  - [remove](#remove)
  - [prune](#prune)
- [How It Works](#how-it-works)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- Create, open, and remove worktrees with short commands
- Auto-detects whether a branch exists locally, on the remote, or needs to be created
- Numbered worktree list for quick selection — no need to type full branch names
- Status overview with dirty/clean state and ahead/behind tracking
- Pull across all worktrees in one command
- Opens VS Code and a terminal with your coding agent automatically
- Confirmation prompts before destructive actions
- Optional hooks and setup steps (e.g. Husky, config files) on worktree creation

## Installation

### Windows (PowerShell)

1. Open PowerShell and run:

   ```powershell
   code $PROFILE
   ```

   If the file doesn't exist:

   ```powershell
   New-Item -Path $PROFILE -ItemType File -Force
   code $PROFILE
   ```

2. Paste the contents of [`gwt.ps1`](gwt.ps1) into your profile.

3. Save and reload:

   ```powershell
   . $PROFILE
   ```

4. Verify:

   ```powershell
   gwt
   ```

**Requirements:** Git, Windows Terminal (for the `open` command with WSL).

### Linux / macOS (Bash)

1. Add the contents of [`gwt.sh`](gwt.sh) to your `~/.bashrc` or `~/.zshrc`.

2. Reload:

   ```bash
   source ~/.bashrc
   ```

3. Verify:

   ```bash
   gwt
   ```

**Requirements:** Git.

## Commands

All commands are run from your main repository folder.

### add

Create a new worktree. Automatically handles three scenarios: local branch exists, remote branch exists, or brand new branch (created from `main`).

```
gwt add <branch>
```

The folder name is derived from the branch name with `/` and `_` replaced by `-`. For example:

```
gwt add feature/auth/login
# Branch: feature/auth/login
# Folder: ../feature-auth-login
```

After creation, VS Code and a terminal session are opened on the new worktree automatically.

### open

Reopen VS Code and a terminal on an existing worktree. Useful after restarting your machine.

```
gwt open          # interactive picker
gwt open 2        # open worktree #2
```

### list

Show all worktrees with numbered indices.

```
gwt list
```

```
  1) /home/user/repos/monorepo          abc1234 [main]
  2) /home/user/repos/feature-auth      def5678 [feature/auth]
  3) /home/user/repos/fix-api           ghi9012 [fix/api]
```

### status

Show all worktrees with working directory state and sync info.

```
gwt status
```

```
  1) [main] clean /home/user/repos/monorepo
  2) [feature/auth] dirty +2 -1 /home/user/repos/feature-auth
  3) [fix/api] clean +3 /home/user/repos/fix-api
```

- **clean** — no uncommitted changes
- **dirty** — has uncommitted changes
- **+N** — N commits ahead of remote (not yet pushed)
- **-N** — N commits behind remote (not yet pulled)

### pull

Pull latest changes on one or all worktrees.

```
gwt pull          # interactive picker
gwt pull 2        # pull worktree #2
gwt pull all      # pull all worktrees
```

### cd

Navigate your shell to a worktree by number.

```
gwt cd            # interactive picker
gwt cd 2          # navigate to worktree #2
```

### remove

Remove a worktree and its local branch. Shows what will be removed and asks for confirmation.

```
gwt remove        # interactive picker
gwt remove 3      # remove worktree #3
```

If the worktree has uncommitted changes, you'll be prompted to force-remove. The main worktree is protected and cannot be removed.

### prune

Clean up stale worktree references (e.g. after manually deleting a worktree folder).

```
gwt prune
```

## How It Works

Git worktrees let you check out multiple branches simultaneously in separate directories, all sharing the same `.git` history. This means:

- No re-cloning — every worktree shares the same repo data
- Each branch gets its own working directory
- Commits, pushes, and pulls are independent per worktree
- Your main checkout becomes the "main worktree"

A typical folder structure:

```
~/repos/
  monorepo/                ← main worktree (main branch)
  feature-auth-login/      ← worktree (agent 1)
  fix-api-validation/      ← worktree (agent 2)
  feature-dashboard/       ← worktree (agent 3)
```

Each folder can have its own VS Code window and coding agent running independently, creating separate PRs without conflicts.

## Customization

The `add` command includes optional post-setup steps that you can tailor to your project. These are defined inside the `add` block and run after the worktree is created.

**Examples of things you might add:**

```powershell
# Install git hooks (e.g. Husky)
npx husky install

# Create config files
'{}' | Out-File -FilePath "local.settings.json" -Encoding utf8

# Restore dependencies
dotnet restore
npm install
```

```bash
# Bash equivalent
npx husky install
echo '{}' > local.settings.json
dotnet restore
npm install
```

Edit the `add` block in your script to match your project's needs.

Similarly, the `open` and `add` commands launch VS Code (`code .`) and a terminal session by default. You can change the terminal command to match your setup — for example, launching a specific shell, starting a dev server, or running a coding agent.

## Troubleshooting

**Detached HEAD after creating worktree from remote branch**
If you see `(detached HEAD)` in `git worktree list`, the branch wasn't created as a local tracking branch. The `gwt add` command handles this automatically, but if you created the worktree manually, fix it with:

```bash
cd /path/to/worktree
git checkout -b branch-name origin/branch-name
```

**Husky hooks fail in worktree**
Worktrees have a `.git` file instead of a `.git` folder, which can confuse Husky. Run `npx husky install` inside the worktree, or add it to the `add` command (see [Customization](#customization)).

**Cannot remove worktree — files in use**
Close VS Code and any terminal sessions on the worktree before removing. If the folder remains after `gwt remove`, delete it manually and run `gwt prune`.

**Stale worktree references**
If you deleted a worktree folder manually, run `gwt prune` to clean up git's internal tracking.

**"Branch already exists" error on add**
The branch exists locally but isn't tied to a worktree. `gwt add` handles this by detecting existing local branches and using them directly.

## License

MIT — free to use, modify, and distribute. No attribution required.
