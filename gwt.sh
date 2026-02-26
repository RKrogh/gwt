#!/usr/bin/env bash

# gwt — Git Worktree Manager
# Add this to your ~/.bashrc or ~/.zshrc, or source it directly.

# -------------------------------------------------------------------
# Configuration — customize these to match your project
# -------------------------------------------------------------------
# Post-setup commands run after creating a worktree (e.g. install hooks, create config files).
# Comment out or modify as needed.
GWT_POST_SETUP() {
    npx husky install 2>/dev/null
    echo '{}' > local.settings.json
}

# Command to open your editor on the worktree folder.
GWT_OPEN_EDITOR() {
    code "$1"
}

# Command to open a terminal with your coding agent.
# Modify this to match your terminal emulator and agent.
# Examples:
#   macOS Terminal.app:  osascript -e "tell app \"Terminal\" to do script \"cd '$1' && claude\""
#   macOS iTerm2:        osascript -e "tell app \"iTerm\" to create window with default profile command \"cd '$1' && claude\""
#   gnome-terminal:      gnome-terminal --working-directory="$1" -- bash -ic "claude; exec bash"
#   kitty:               kitty --directory "$1" bash -ic "claude; exec bash"
#   tmux:                tmux new-window -c "$1" "claude; exec bash"
GWT_OPEN_AGENT() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "tell app \"Terminal\" to do script \"cd '$1' && claude\""
    elif command -v gnome-terminal &>/dev/null; then
        gnome-terminal --working-directory="$1" -- bash -ic "claude; exec bash"
    elif command -v kitty &>/dev/null; then
        kitty --directory "$1" bash -ic "claude; exec bash" &
    elif command -v tmux &>/dev/null && [ -n "$TMUX" ]; then
        tmux new-window -c "$1" "claude; exec bash"
    else
        echo "Start your agent manually: cd $1 && claude"
    fi
}

# -------------------------------------------------------------------
# Main function
# -------------------------------------------------------------------
gwt() {
    local command="$1"
    local branch="$2"

    case "$command" in
        add)
            if [ -z "$branch" ]; then
                echo -e "\033[31mUsage: gwt add <branch>\033[0m"
                return
            fi

            local folder="../${branch//[\/\_]/-}"

            if git rev-parse --verify "$branch" &>/dev/null; then
                git worktree add "$folder" "$branch"
            elif git rev-parse --verify "origin/$branch" &>/dev/null; then
                git worktree add -b "$branch" "$folder" "origin/$branch"
            else
                git worktree add -b "$branch" "$folder" main
            fi

            if [ $? -ne 0 ]; then
                echo -e "\033[31mFailed to create worktree\033[0m"
                return
            fi

            (
                cd "$folder" || return
                GWT_POST_SETUP
            )

            local fullpath
            fullpath=$(cd "$folder" && pwd)

            echo -e "\033[32mWorktree ready at $folder\033[0m"
            GWT_OPEN_EDITOR "$fullpath"
            GWT_OPEN_AGENT "$fullpath"
            ;;

        open)
            local worktrees
            mapfile -t worktrees < <(git worktree list)

            if [[ "$branch" =~ ^[0-9]+$ ]]; then
                local index=$((branch - 1))
            else
                echo -e "\n\033[36mWorktrees:\033[0m"
                for i in "${!worktrees[@]}"; do
                    echo "  $((i + 1))) ${worktrees[$i]}"
                done
                read -rp $'\nSelect number to open (or q to cancel): ' pick
                [ "$pick" = "q" ] && return
                local index=$((pick - 1))
            fi

            if [ "$index" -lt 0 ] || [ "$index" -ge "${#worktrees[@]}" ]; then
                echo -e "\033[31mInvalid number. Pick 1-${#worktrees[@]}\033[0m"
                return
            fi

            local path
            path=$(echo "${worktrees[$index]}" | awk '{print $1}')

            GWT_OPEN_EDITOR "$path"
            GWT_OPEN_AGENT "$path"

            echo -e "\033[32mOpened worktree at $path\033[0m"
            ;;

        remove)
            local worktrees
            mapfile -t worktrees < <(git worktree list)

            if [ "${#worktrees[@]}" -le 1 ]; then
                echo -e "\033[33mNo worktrees to remove (only main exists)\033[0m"
                return
            fi

            if [[ "$branch" =~ ^[0-9]+$ ]]; then
                local index=$((branch - 1))
            else
                echo -e "\n\033[36mWorktrees:\033[0m"
                for i in "${!worktrees[@]}"; do
                    echo "  $((i + 1))) ${worktrees[$i]}"
                done
                read -rp $'\nSelect number to remove (or q to cancel): ' pick
                [ "$pick" = "q" ] && return
                local index=$((pick - 1))
            fi

            if [ "$index" -lt 0 ] || [ "$index" -ge "${#worktrees[@]}" ]; then
                echo -e "\033[31mInvalid number. Pick 1-${#worktrees[@]}\033[0m"
                return
            fi

            local selected="${worktrees[$index]}"

            if echo "$selected" | grep -q '\[main\]'; then
                echo -e "\033[31mCannot remove main worktree\033[0m"
                return
            fi

            local path branchName
            path=$(echo "$selected" | awk '{print $1}')
            branchName=$(echo "$selected" | grep -oP '\[(.+?)\]' | tr -d '[]')

            echo -e "\033[33mRemove worktree?\033[0m"
            echo "  Path:   $path"
            echo "  Branch: $branchName"
            read -rp "Continue? (y/n): " confirm
            [ "$confirm" != "y" ] && { echo -e "\033[33mCancelled\033[0m"; return; }

            if ! git worktree remove "$path" 2>/dev/null; then
                read -rp "Worktree has changes. Force remove? (y/n): " force
                if [ "$force" = "y" ]; then
                    git worktree remove --force "$path"
                    if [ -d "$path" ]; then
                        echo -e "\033[33mClose editors and terminals on this worktree, then press Enter...\033[0m"
                        read -r
                        rm -rf "$path"
                        if [ -d "$path" ]; then
                            echo -e "\033[33mCould not fully delete folder. Remove manually: $path\033[0m"
                        fi
                    fi
                else
                    echo -e "\033[33mCancelled\033[0m"
                    return
                fi
            fi

            if [ -n "$branchName" ]; then
                if ! git branch -d "$branchName" 2>/dev/null; then
                    echo -e "\033[33mNote: branch '$branchName' not deleted (unmerged or still in use)\033[0m"
                fi
            fi
            git worktree prune
            echo -e "\033[32mRemoved worktree and branch\033[0m"
            ;;

        status)
            local worktrees
            mapfile -t worktrees < <(git worktree list)

            echo -e "\n\033[36mWorktree Status:\033[0m"
            for i in "${!worktrees[@]}"; do
                local path branchInfo dirty ahead behind state stateColor sync
                path=$(echo "${worktrees[$i]}" | awk '{print $1}')
                branchInfo=$(echo "${worktrees[$i]}" | grep -oP '\[(.+?)\]' | tr -d '[]')
                [ -z "$branchInfo" ] && branchInfo="detached"

                dirty=$(git -C "$path" status --porcelain)
                ahead=$(git -C "$path" rev-list --count '@{u}..HEAD' 2>/dev/null)
                behind=$(git -C "$path" rev-list --count 'HEAD..@{u}' 2>/dev/null)

                if [ -n "$dirty" ]; then
                    state="dirty"
                    stateColor="\033[33m"
                else
                    state="clean"
                    stateColor="\033[32m"
                fi

                sync=""
                [ -n "$ahead" ] && [ "$ahead" != "0" ] && sync+=" +$ahead"
                [ -n "$behind" ] && [ "$behind" != "0" ] && sync+=" -$behind"

                printf "  %d) \033[36m[%s]\033[0m ${stateColor}%s\033[0m" $((i + 1)) "$branchInfo" "$state"
                [ -n "$sync" ] && printf " \033[35m%s\033[0m" "$sync"
                printf " %s\n" "$path"
            done
            ;;

        pull)
            local worktrees
            mapfile -t worktrees < <(git worktree list)
            local selected=()

            if [[ "$branch" =~ ^[0-9]+$ ]]; then
                local index=$((branch - 1))
                if [ "$index" -lt 0 ] || [ "$index" -ge "${#worktrees[@]}" ]; then
                    echo -e "\033[31mInvalid number. Pick 1-${#worktrees[@]}\033[0m"
                    return
                fi
                selected=("${worktrees[$index]}")
            elif [ "$branch" = "all" ]; then
                selected=("${worktrees[@]}")
            else
                echo -e "\n\033[36mWorktrees:\033[0m"
                for i in "${!worktrees[@]}"; do
                    echo "  $((i + 1))) ${worktrees[$i]}"
                done
                read -rp $'\nSelect number to pull, or \'all\' (or q to cancel): ' pick
                [ "$pick" = "q" ] && return
                if [ "$pick" = "all" ]; then
                    selected=("${worktrees[@]}")
                else
                    local index=$((pick - 1))
                    if [ "$index" -lt 0 ] || [ "$index" -ge "${#worktrees[@]}" ]; then
                        echo -e "\033[31mInvalid number.\033[0m"
                        return
                    fi
                    selected=("${worktrees[$index]}")
                fi
            fi

            for wt in "${selected[@]}"; do
                local path branchInfo
                path=$(echo "$wt" | awk '{print $1}')
                branchInfo=$(echo "$wt" | grep -oP '\[(.+?)\]' | tr -d '[]')
                echo -e "\033[36mPulling $branchInfo...\033[0m"
                git -C "$path" pull
            done
            echo -e "\033[32mDone\033[0m"
            ;;

        cd)
            local worktrees
            mapfile -t worktrees < <(git worktree list)

            if [[ "$branch" =~ ^[0-9]+$ ]]; then
                local index=$((branch - 1))
            else
                echo -e "\n\033[36mWorktrees:\033[0m"
                for i in "${!worktrees[@]}"; do
                    echo "  $((i + 1))) ${worktrees[$i]}"
                done
                read -rp $'\nSelect number (or q to cancel): ' pick
                [ "$pick" = "q" ] && return
                local index=$((pick - 1))
            fi

            if [ "$index" -lt 0 ] || [ "$index" -ge "${#worktrees[@]}" ]; then
                echo -e "\033[31mInvalid number. Pick 1-${#worktrees[@]}\033[0m"
                return
            fi

            local path
            path=$(echo "${worktrees[$index]}" | awk '{print $1}')
            cd "$path" || return
            ;;

        prune)
            git worktree prune
            echo -e "\033[32mPruned stale worktrees\033[0m"
            ;;

        list)
            local worktrees
            mapfile -t worktrees < <(git worktree list)
            for i in "${!worktrees[@]}"; do
                echo "  $((i + 1))) ${worktrees[$i]}"
            done
            ;;

        *)
            echo -e "\033[33mUsage: gwt <command> [branch|number]\033[0m"
            echo "  add <branch>       Create worktree"
            echo "  open [number]      Open editor + agent on existing worktree"
            echo "  remove [number]    Remove worktree (interactive if no number)"
            echo "  status             Show all worktrees with dirty/clean and ahead/behind"
            echo "  pull [number|all]  Pull latest on one or all worktrees"
            echo "  cd [number]        Navigate to a worktree"
            echo "  prune              Clean up stale references"
            echo "  list               List all worktrees (numbered)"
            ;;
    esac
}
