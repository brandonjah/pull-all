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
   echo 'alias pullall="~/code/pull-all/pull-all.sh"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. Run it:

   ```bash
   pullall
   ```

## Configuration

By default the script syncs all repos under `~/code/homebot`. To change the target directory, edit the `HOMEBOT_DIR` variable at the top of `pull-all.sh`:

```bash
HOMEBOT_DIR="$HOME/code/homebot"
```
