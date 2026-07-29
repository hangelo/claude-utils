#!/bin/bash
# Status line converted from ~/.bash_prompt PS1:
#   \u@\h: \w [branch dirty-bits]
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

username=$(whoami)
hostname=$(hostname -s)

# Abbreviate $HOME as ~ (mirrors bash's \w behavior)
display_dir="${cwd/#$HOME/~}"

# git branch + dirty-state bits (mirrors parse_git_branch/parse_git_dirty)
git_info=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        status=$(git -C "$cwd" --no-optional-locks status 2>&1)
        bits=""
        echo "$status" | grep -q "renamed:" && bits=">${bits}"
        echo "$status" | grep -q "Your branch is ahead of" && bits="*${bits}"
        echo "$status" | grep -q "new file:" && bits="+${bits}"
        echo "$status" | grep -q "Untracked files" && bits="?${bits}"
        echo "$status" | grep -q "deleted:" && bits="x${bits}"
        echo "$status" | grep -q "modified:" && bits="!${bits}"
        stat=""
        if [ -n "$bits" ]; then
            stat=" ${bits}"
        fi
        git_info="[${branch}${stat}]"
    fi
fi

# context window: percentage used + tokens used/total, color-coded
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx_used=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')

ctx_info=""
if [ -n "$ctx_pct" ] && [ -n "$ctx_size" ]; then
    ctx_pct=${ctx_pct%%.*}
    if [ "$ctx_pct" -lt 50 ]; then
        ctx_color='\033[32m' # green
    elif [ "$ctx_pct" -lt 75 ]; then
        ctx_color='\033[33m' # yellow
    else
        ctx_color='\033[31m' # red
    fi
    used_k=$((ctx_used / 1000))
    size_k=$((ctx_size / 1000))
    ctx_info=$(printf '%b%s%%%b %sk/%sk' "$ctx_color" "$ctx_pct" '\033[0m' "$used_k" "$size_k")
fi

# sf default org: shown only inside an SFDX project (walk up to sfdx-project.json).
# Reads .sf/config.json directly instead of `sf config get` — the CLI is too slow
# for a statusline that re-renders on every turn.
sf_info=""
dir="$cwd"
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/sfdx-project.json" ]; then
        sf_org=$(jq -r '."target-org" // empty' "$dir/.sf/config.json" 2>/dev/null)
        if [ -z "$sf_org" ]; then
            sf_org=$(jq -r '."target-org" // empty' ~/.sf/config.json 2>/dev/null)
        fi
        # servicedev is the only org this machine should target; anything else
        # (including none) renders red as a wrong-org tripwire.
        if [ "$sf_org" = "servicedev" ]; then
            sf_info=$(printf '\033[32m⚡%s\033[0m' "$sf_org")
        else
            sf_info=$(printf '\033[31m⚡%s\033[0m' "${sf_org:-no-org}")
        fi
        break
    fi
    dir=$(dirname "$dir")
done

# session cost + line churn
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_del=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cost_info=""
if [ -n "$cost_usd" ]; then
    cost_info=$(printf '$%.2f \033[32m+%s\033[0m/\033[31m-%s\033[0m' "$cost_usd" "$lines_add" "$lines_del")
fi

# session duration
dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
dur_info=""
if [ -n "$dur_ms" ]; then
    dur_min=$((dur_ms / 60000))
    if [ "$dur_min" -ge 60 ]; then
        dur_info=$(printf '%dh%02dm' $((dur_min / 60)) $((dur_min % 60)))
    else
        dur_info="${dur_min}m"
    fi
fi

# session info: model display name + reasoning effort level
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
if [ -z "$effort" ]; then
    effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
fi

session_info=""
if [ -n "$model_name" ] && [ -n "$effort" ]; then
    session_info="[${model_name} · ${effort}]"
elif [ -n "$model_name" ]; then
    session_info="[${model_name}]"
elif [ -n "$effort" ]; then
    session_info="[${effort}]"
fi

line="$(printf '\033[32m%s@%s\033[0m: \033[36m%s\033[0m \033[35m%s\033[0m \033[33m%s\033[0m' "$username" "$hostname" "$display_dir" "$git_info" "$session_info")"
# sf org onward: dim │ separator before each group that is present
sep=$(printf ' \033[90m│\033[0m ')
for seg in "$sf_info" "$ctx_info" "$cost_info" "$dur_info"; do
    if [ -n "$seg" ]; then
        line="${line}${sep}${seg}"
    fi
done
printf '%s' "$line"
