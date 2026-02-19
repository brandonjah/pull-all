#!/bin/bash

# pull-all.sh — Check out the default branch and pull latest for all repos in a directory
# Usage: ./pull-all.sh [--docker] [directory]
#        PULL_ALL_DIR=~/code/myproject ./pull-all.sh

DOCKER_UP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker|-d)
      DOCKER_UP=true
      shift
      ;;
    --help|-h)
      echo "Usage: pull-all [--docker] <directory>"
      echo ""
      echo "Options:"
      echo "  --docker, -d   Start docker compose services for repos that have a compose file"
      echo ""
      echo "The target directory can also be set via PULL_ALL_DIR environment variable."
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Run 'pull-all --help' for usage."
      exit 1
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-${PULL_ALL_DIR:-}}"

if [ -z "$TARGET_DIR" ]; then
  echo "Usage: pull-all [--docker] <directory>"
  echo "   or: export PULL_ALL_DIR=~/code/myproject"
  exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd)

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: '$TARGET_DIR' is not a valid directory."
  exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

success_count=0
skip_count=0
fail_count=0

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Pull All — $(basename "$TARGET_DIR")${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

for dir in "$TARGET_DIR"/*/; do
  # Skip non-git directories
  [ -d "$dir/.git" ] || continue

  repo_name=$(basename "$dir")
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📂 $repo_name${NC}"

  cd "$dir" || continue

  # Determine default branch (main or master)
  default_branch=""
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    default_branch="main"
  elif git show-ref --verify --quiet refs/remotes/origin/master; then
    default_branch="master"
  else
    # Fallback: check origin/HEAD
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  fi

  if [ -z "$default_branch" ]; then
    echo -e "${RED}   Could not determine default branch. Skipping.${NC}"
    ((skip_count++))
    echo ""
    continue
  fi

  echo -e "   Default branch: ${GREEN}$default_branch${NC}"

  # Check current state
  current_branch=$(git branch --show-current)
  has_changes=false

  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    has_changes=true
  fi

  # --- Handle uncommitted changes ---
  if [ "$has_changes" = true ]; then
    echo -e "${YELLOW}   ⚠  Uncommitted changes on branch '$current_branch'${NC}"
    echo ""
    git -C "$dir" status --short | head -10 | sed 's/^/      /'
    changed_count=$(git -C "$dir" status --short | wc -l | tr -d ' ')
    if [ "$changed_count" -gt 10 ]; then
      echo -e "      ${YELLOW}... and $((changed_count - 10)) more files${NC}"
    fi
    echo ""

    read -r -p "   Stash changes? (y/n) " stash_answer
    case "$stash_answer" in
      [yY]|[yY][eE][sS])
        echo -e "   Stashing changes..."
        git stash push -m "pull-all auto-stash $(date '+%Y-%m-%d %H:%M:%S')"
        if [ $? -ne 0 ]; then
          echo -e "${RED}   Failed to stash. Skipping repo.${NC}"
          ((fail_count++))
          echo ""
          continue
        fi
        echo -e "${GREEN}   Stashed successfully.${NC}"
        ;;
      *)
        echo -e "${YELLOW}   No stash — skipping $repo_name.${NC}"
        ((skip_count++))
        echo ""
        continue
        ;;
    esac
  fi

  # --- Handle being on a different branch ---
  if [ "$current_branch" != "$default_branch" ]; then
    echo -e "${YELLOW}   Currently on branch '$current_branch' (not '$default_branch')${NC}"
    read -r -p "   Switch to $default_branch? (y/n) " switch_answer
    case "$switch_answer" in
      [yY]|[yY][eE][sS])
        echo -e "   Switching to '$default_branch'..."
        git checkout "$default_branch" 2>&1 | sed 's/^/      /'
        if [ $? -ne 0 ]; then
          echo -e "${RED}   Failed to checkout $default_branch. Skipping repo.${NC}"
          ((fail_count++))
          echo ""
          continue
        fi
        ;;
      *)
        echo -e "${YELLOW}   Staying on '$current_branch' — skipping $repo_name.${NC}"
        ((skip_count++))
        echo ""
        continue
        ;;
    esac
  fi

  # --- Pull latest ---
  echo -e "   Pulling latest on $default_branch..."
  pull_output=$(git pull 2>&1)
  pull_status=$?

  if [ $pull_status -ne 0 ]; then
    echo -e "${RED}   Pull failed:${NC}"
    echo "$pull_output" | sed 's/^/      /'
    ((fail_count++))
  else
    if echo "$pull_output" | grep -q "Already up to date"; then
      echo -e "${GREEN}   Already up to date.${NC}"
    else
      echo "$pull_output" | tail -3 | sed 's/^/      /'
      echo -e "${GREEN}   Pulled successfully.${NC}"
    fi
    ((success_count++))

    # --- Rails post-pull tasks ---
    if [ -f "$dir/bin/rails" ] && [ -f "$dir/Gemfile" ]; then
      echo -e "${BLUE}   🛤  Rails repo detected${NC}"

      if echo "$pull_output" | grep -q "Gemfile\|Gemfile.lock"; then
        echo -e "   Running ${BOLD}bundle install${NC}..."
        bundle_output=$(bundle install 2>&1)
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}   Bundle install succeeded.${NC}"
        else
          echo -e "${RED}   Bundle install failed:${NC}"
          echo "$bundle_output" | tail -5 | sed 's/^/      /'
        fi
      fi

      if echo "$pull_output" | grep -q "db/migrate"; then
        echo -e "   Running ${BOLD}rails db:migrate${NC}..."
        migrate_output=$(bin/rails db:migrate 2>&1)
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}   Migrations succeeded.${NC}"
        else
          echo -e "${RED}   Migrations failed:${NC}"
          echo "$migrate_output" | tail -5 | sed 's/^/      /'
        fi
      fi
    fi

    # --- JavaScript/Node post-pull tasks ---
    if [ -f "$dir/package.json" ]; then
      if echo "$pull_output" | grep -q "package.json\|package-lock.json\|yarn.lock\|pnpm-lock.yaml"; then
        if [ -f "$dir/pnpm-lock.yaml" ]; then
          echo -e "${BLUE}   📦 pnpm project detected${NC}"
          echo -e "   Running ${BOLD}pnpm install${NC}..."
          js_install_output=$(pnpm install 2>&1)
        elif [ -f "$dir/yarn.lock" ]; then
          echo -e "${BLUE}   📦 Yarn project detected${NC}"
          echo -e "   Running ${BOLD}yarn install${NC}..."
          js_install_output=$(yarn install 2>&1)
        else
          echo -e "${BLUE}   📦 npm project detected${NC}"
          echo -e "   Running ${BOLD}npm install${NC}..."
          js_install_output=$(npm install 2>&1)
        fi

        if [ $? -eq 0 ]; then
          echo -e "${GREEN}   Install succeeded.${NC}"
        else
          echo -e "${RED}   Install failed:${NC}"
          echo "$js_install_output" | tail -5 | sed 's/^/      /'
        fi
      fi
    fi

    # --- Docker Compose ---
    if [ "$DOCKER_UP" = true ]; then
      compose_file=""
      for f in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if [ -f "$dir/$f" ]; then
          compose_file="$f"
          break
        fi
      done

      if [ -n "$compose_file" ]; then
        echo -e "${BLUE}   🐳 Docker Compose detected ($compose_file)${NC}"

        running_services=$(docker compose ps --status running --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')

        if [ "$running_services" -gt 0 ]; then
          echo -e "${GREEN}   Already running ($running_services service(s) up).${NC}"
          echo -e "   Running ${BOLD}docker compose up -d${NC} to pick up changes..."
        else
          echo -e "   Starting services with ${BOLD}docker compose up -d${NC}..."
        fi

        compose_output=$(docker compose up -d 2>&1)
        if [ $? -eq 0 ]; then
          new_running=$(docker compose ps --status running --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')
          echo -e "${GREEN}   Docker Compose up ($new_running service(s) running).${NC}"
        else
          echo -e "${RED}   Docker Compose failed:${NC}"
          echo "$compose_output" | tail -5 | sed 's/^/      /'
        fi
      fi
    fi
  fi

  echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}Summary:${NC}"
echo -e "  ${GREEN}✓ Updated: $success_count${NC}"
echo -e "  ${YELLOW}⊘ Skipped: $skip_count${NC}"
echo -e "  ${RED}✗ Failed:  $fail_count${NC}"
echo ""
