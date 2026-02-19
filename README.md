# pull-all

Batch-pull all git repos in a directory. Checks out the default branch, pulls latest, and runs post-pull tasks automatically:

- **Rails repos** — runs `bundle install` (if Gemfile changed) and `rails db:migrate` (if new migrations)
- **JS/Node repos** — runs `npm install`, `yarn install`, or `pnpm install` (if lockfile/package.json changed), auto-detecting the package manager

Handles uncommitted changes (offers to stash) and non-default branches (offers to switch) interactively.

## Setup

1. Clone this repo:

   ```bash
   git clone git@github.com:brandonjah/pull-all.git ~/code/pull-all
   ```

2. Make the script executable:

   ```bash
   chmod +x ~/code/pull-all/pull-all.sh
   ```

3. Add an alias to your `~/.zshrc`:

   ```bash
   # Option A: pass the directory each time
   alias pullall="~/code/pull-all/pull-all.sh"

   # Option B: set a default directory via environment variable
   export PULL_ALL_DIR="$HOME/code/myproject"
   alias pullall="~/code/pull-all/pull-all.sh"
   ```

4. Reload your shell:

   ```bash
   source ~/.zshrc
   ```

## Usage

```bash
# Pass a directory as an argument
pullall ~/code/myproject

# Or use the PULL_ALL_DIR environment variable
export PULL_ALL_DIR=~/code/myproject
pullall

# Argument takes priority over the environment variable
pullall ~/code/other-project
```
