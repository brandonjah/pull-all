# pull-all

Batch-pull all git repos in a directory. Checks out the default branch, pulls latest, and runs post-pull tasks automatically:

- **Rails repos** — runs `bundle install` (if Gemfile changed) and `rails db:migrate` (if new migrations)
- **JS/Node repos** — runs `npm install`, `yarn install`, or `pnpm install` (if lockfile/package.json changed), auto-detecting the package manager
- **Docker Compose** — optionally starts services with `docker compose up -d`, gracefully handling already-running containers

Handles uncommitted changes (offers to stash) and non-default branches (offers to switch) interactively.

## Setup

1. Clone this repo somewhere on your machine:

   ```bash
   git clone git@github.com:brandonjah/pull-all.git /path/to/pull-all
   ```

2. Make the script executable:

   ```bash
   chmod +x /path/to/pull-all/pull-all.sh
   ```

3. Add an alias to your `~/.zshrc`:

   ```bash
   # Option A: pass the directory each time
   alias pullall="/path/to/pull-all/pull-all.sh"

   # Option B: set a default directory via environment variable
   export PULL_ALL_DIR="/path/to/your/repos"
   alias pullall="/path/to/pull-all/pull-all.sh"
   ```

4. Reload your shell:

   ```bash
   source ~/.zshrc
   ```

## Usage

```bash
# Pass a directory as an argument
pullall /path/to/your/repos

# Or use the PULL_ALL_DIR environment variable
export PULL_ALL_DIR=/path/to/your/repos
pullall

# Argument takes priority over the environment variable
pullall /path/to/other/repos

# Also start docker compose services
pullall --docker /path/to/your/repos
pullall -d
```

## Options

| Flag | Description |
|------|-------------|
| `--docker`, `-d` | Start docker compose services for repos that have a compose file |
| `--help`, `-h` | Show usage information |
