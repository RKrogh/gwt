function gwt {
    param(
        [string]$command,
        [string]$branch
    )

    switch ($command) {
        "add" {
            if (-not $branch) { Write-Host "Usage: gwt add <branch>" -ForegroundColor Red; return }
            $folder = "../$($branch -replace '[/\\_]', '-')"

            # Determine how to create the worktree
            if (git rev-parse --verify "$branch" 2>$null) {
                # Local branch already exists
                git worktree add $folder $branch
            } elseif (git rev-parse --verify "origin/$branch" 2>$null) {
                # Remote branch exists, create local tracking branch
                git worktree add -b $branch $folder "origin/$branch"
            } else {
                # Brand new branch off main
                git worktree add -b $branch $folder main
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to create worktree" -ForegroundColor Red
                return
            }

            Push-Location $folder
            npx husky install
            '{}' | Out-File -FilePath "local.settings.json" -Encoding utf8
            Write-Host "Worktree ready at $folder" -ForegroundColor Green
            code .

            $fullPath = (Resolve-Path .).Path -replace '\\', '/' -replace 'C:', '/mnt/c'
            wt new-tab -p "Ubuntu" -- wsl bash -ic "cd '$fullPath' && claude"

            Pop-Location
        }
        "open" {
            $worktrees = @(git worktree list)

            if ($branch -match '^\d+$') {
                $index = [int]$branch - 1
            } else {
                Write-Host "`nWorktrees:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $worktrees.Count; $i++) {
                    Write-Host "  $($i + 1)) $($worktrees[$i])"
                }
                $pick = Read-Host "`nSelect number to open (or 'q' to cancel)"
                if ($pick -eq 'q') { return }
                $index = [int]$pick - 1
            }

            if ($index -lt 0 -or $index -ge $worktrees.Count) {
                Write-Host "Invalid number. Pick 1-$($worktrees.Count)" -ForegroundColor Red
                return
            }

            $selected = $worktrees[$index]
            $path = ($selected -split '\s+')[0]

            Push-Location $path
            code .
            $fullPath = (Resolve-Path .).Path -replace '\\', '/' -replace 'C:', '/mnt/c'
            wt new-tab -p "Ubuntu" -- wsl bash -ic "cd '$fullPath' && claude"
            Pop-Location

            Write-Host "Opened worktree at $path" -ForegroundColor Green
        }
        "remove" {
            $worktrees = @(git worktree list)

            if ($worktrees.Count -le 1) {
                Write-Host "No worktrees to remove (only main exists)" -ForegroundColor Yellow
                return
            }

            if ($branch -match '^\d+$') {
                $index = [int]$branch - 1
            } else {
                Write-Host "`nWorktrees:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $worktrees.Count; $i++) {
                    Write-Host "  $($i + 1)) $($worktrees[$i])"
                }
                $pick = Read-Host "`nSelect number to remove (or 'q' to cancel)"
                if ($pick -eq 'q') { return }
                $index = [int]$pick - 1
            }

            if ($index -lt 0 -or $index -ge $worktrees.Count) {
                Write-Host "Invalid number. Pick 1-$($worktrees.Count)" -ForegroundColor Red
                return
            }

            $selected = $worktrees[$index]

            if ($selected -match '\[main\]') {
                Write-Host "Cannot remove main worktree" -ForegroundColor Red
                return
            }

            $path = ($selected -split '\s+')[0]
            $branchName = if ($selected -match '\[(.+)\]') { $matches[1] } else { $null }

            Write-Host "Remove worktree?" -ForegroundColor Yellow
            Write-Host "  Path:   $path"
            Write-Host "  Branch: $branchName"
            $confirm = Read-Host "Continue? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "Cancelled" -ForegroundColor Yellow
                return
            }

            git worktree remove $path
            if ($LASTEXITCODE -ne 0) {
                $force = Read-Host "Worktree has changes. Force remove? (y/n)"
                if ($force -eq 'y') {
                    git worktree remove --force $path
                    if (Test-Path $path) {
                        Write-Host "Close VS Code and any terminals on this worktree, then press Enter..." -ForegroundColor Yellow
                        Read-Host
                        Remove-Item -Recurse -Force $path
                        if (Test-Path $path) {
                            Write-Host "Could not fully delete folder. Remove manually: $path" -ForegroundColor Yellow
                        }
                    }
                }
                else {
                    Write-Host "Cancelled" -ForegroundColor Yellow
                    return
                }
            }

            if ($branchName) { 
                git branch -d $branchName 
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Note: branch '$branchName' not deleted (unmerged or still in use)" -ForegroundColor Yellow
                }
            }
            git worktree prune
            Write-Host "Removed worktree and branch" -ForegroundColor Green
        }
        "status" {
            $worktrees = @(git worktree list)
            Write-Host "`nWorktree Status:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $worktrees.Count; $i++) {
                $path = ($worktrees[$i] -split '\s+')[0]
                $branchInfo = if ($worktrees[$i] -match '\[(.+)\]') { $matches[1] } else { "detached" }
                
                Push-Location $path
                $dirty = git status --porcelain
                $ahead = git rev-list --count '@{u}..HEAD' 2>$null
                $behind = git rev-list --count 'HEAD..@{u}' 2>$null
                Pop-Location

                $state = if ($dirty) { "dirty" } else { "clean" }
                $stateColor = if ($dirty) { "Yellow" } else { "Green" }
                $sync = ""
                if ($ahead -and $ahead -ne "0") { $sync += " +$ahead" }
                if ($behind -and $behind -ne "0") { $sync += " -$behind" }

                Write-Host "  $($i + 1)) " -NoNewline
                Write-Host "[$branchInfo]" -NoNewline -ForegroundColor Cyan
                Write-Host " $state" -NoNewline -ForegroundColor $stateColor
                if ($sync) { Write-Host $sync -NoNewline -ForegroundColor Magenta }
                Write-Host " $path"
            }
        }
        "pull" {
            $worktrees = @(git worktree list)

            if ($branch -match '^\d+$') {
                $index = [int]$branch - 1
                if ($index -lt 0 -or $index -ge $worktrees.Count) {
                    Write-Host "Invalid number. Pick 1-$($worktrees.Count)" -ForegroundColor Red
                    return
                }
                $selected = @($worktrees[$index])
            } elseif ($branch -eq "all") {
                $selected = $worktrees
            } else {
                Write-Host "`nWorktrees:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $worktrees.Count; $i++) {
                    Write-Host "  $($i + 1)) $($worktrees[$i])"
                }
                $pick = Read-Host "`nSelect number to pull, or 'all' (or 'q' to cancel)"
                if ($pick -eq 'q') { return }
                if ($pick -eq 'all') {
                    $selected = $worktrees
                } else {
                    $index = [int]$pick - 1
                    if ($index -lt 0 -or $index -ge $worktrees.Count) {
                        Write-Host "Invalid number." -ForegroundColor Red
                        return
                    }
                    $selected = @($worktrees[$index])
                }
            }

            foreach ($wt in $selected) {
                $path = ($wt -split '\s+')[0]
                $branchInfo = if ($wt -match '\[(.+)\]') { $matches[1] } else { "unknown" }
                Write-Host "Pulling $branchInfo..." -ForegroundColor Cyan
                Push-Location $path
                git pull
                Pop-Location
            }
            Write-Host "Done" -ForegroundColor Green
        }
        "cd" {
            $worktrees = @(git worktree list)

            if ($branch -match '^\d+$') {
                $index = [int]$branch - 1
            } else {
                Write-Host "`nWorktrees:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $worktrees.Count; $i++) {
                    Write-Host "  $($i + 1)) $($worktrees[$i])"
                }
                $pick = Read-Host "`nSelect number (or 'q' to cancel)"
                if ($pick -eq 'q') { return }
                $index = [int]$pick - 1
            }

            if ($index -lt 0 -or $index -ge $worktrees.Count) {
                Write-Host "Invalid number. Pick 1-$($worktrees.Count)" -ForegroundColor Red
                return
            }

            $path = ($worktrees[$index] -split '\s+')[0]
            Set-Location $path
        }
        "prune" {
            git worktree prune
            Write-Host "Pruned stale worktrees" -ForegroundColor Green
        }
        "list" {
            $worktrees = @(git worktree list)
            for ($i = 0; $i -lt $worktrees.Count; $i++) {
                Write-Host "  $($i + 1)) $($worktrees[$i])"
            }
        }
        default {
            Write-Host "Usage: gwt <command> [branch|number]" -ForegroundColor Yellow
            Write-Host "  add <branch>       Create worktree"
            Write-Host "  open [number]      Open VS Code + Claude on existing worktree"
            Write-Host "  remove [number]    Remove worktree (interactive if no number)"
            Write-Host "  status             Show all worktrees with dirty/clean and ahead/behind"
            Write-Host "  pull [number|all]  Pull latest on one or all worktrees"
            Write-Host "  cd [number]        Navigate to a worktree"
            Write-Host "  prune              Clean up stale references"
            Write-Host "  list               List all worktrees (numbered)"
        }
    }
}