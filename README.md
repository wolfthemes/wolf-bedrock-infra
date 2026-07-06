# wolf-bedrock-docker

Local Bedrock (Roots) WordPress dev environment run via Docker: nginx + PHP-FPM
+ MySQL, mirroring the repo-split convention from `wolf-store-docker` but for
a Composer-managed Bedrock project.

## First-time setup

```bash
# 1. Scaffold Bedrock into this directory (only if web/ doesn't exist yet)
composer create-project roots/bedrock .

# 2. Copy env and fill in DB creds + salts (https://roots.io/salts.html)
cp .env.example .env

# 3. Add the theme/plugin repos as submodules, at their real Bedrock path
#    (one-time, not a plain clone — same path in dev and prod). -f is
#    required because web/app/{themes,plugins}/* is gitignored (Composer-
#    managed installs live there too) — it doesn't affect the submodule.
git submodule add -f git@github.com:wolfthemes/wolf-blocks.git web/app/plugins/wolf-blocks

# on a later checkout of this repo, pull submodule contents with:
# git submodule update --init --recursive

# 4. Boot the stack (builds the php image, runs composer install --no-dev)
docker compose up -d --build
```

- Site: http://localhost:8080
- Adminer (DB GUI): http://localhost:8081

## Setting up on another machine (from a git clone)

Once the repo exists on GitHub, bringing it up on a fresh machine doesn't need
the scaffolding/submodule-add steps above — just pull the pinned state:

```bash
# 1. Clone (or pull) this repo
git clone git@github.com:wolfthemes/wolf-bedrock-docker.git
cd wolf-bedrock-docker

# 2. Pull the theme/plugin submodules at their pinned commits
git submodule update --init --recursive

# 3. Copy env and fill in DB creds + salts (https://roots.io/salts.html)
cp .env.example .env

# 4. Install Composer deps (WP core + third-party plugins into web/wp, vendor/)
composer install

# 5. Boot the stack
docker compose up -d --build
```

`docker compose up -d --build` runs `composer install` inside the image at
build time, so step 4 is only needed if you want the deps available on the
host (e.g. running Composer/WP-CLI outside Docker).

## Daily workflow

```bash
docker compose up -d       # start
docker compose down        # stop
docker compose logs -f php
```

Re-run `docker compose build php` whenever `composer.json` changes — deps are
installed at image-build time, not via a separate one-off command.

## WP-CLI

WP-CLI is baked into the `php` image. Run it via `docker compose exec`:

```bash
docker compose exec -u www-data php wp <command>
```

To use `wp` directly from WSL without the `docker compose exec php` prefix,
add an alias to `~/.bashrc` (run from this repo's root):

```bash
alias wp='docker compose exec -u www-data php wp'
```

```bash
wp plugin list
wp core is-installed
wp cache flush
```

## Adding plugins

Two ways, depending on origin:

- **wolfthemes' own plugins** (e.g. `wolf-blocks`) — git submodules, added
  per step 3 above.
- **WordPress.org plugins** — Composer, via WPackagist:
  ```bash
  composer require wpackagist-plugin/contact-form-7
  docker compose up -d --build php
  ```
  Installs into `web/app/plugins/{slug}/`, same path Composer-managed
  submodule plugins use, but untracked by git (reinstalled at image-build
  time from `composer.lock`).

## Multisite (subdirectory)

Enabled via env, off by default:

1. Install WP as a normal single site first (already the default flow above).
2. Set `MULTISITE=true` in `.env`.
3. `docker compose up -d --force-recreate php`
4. Manage subsites at `http://localhost:8080/wp/wp-admin/network/`.

`config/nginx.conf` already carries the subdirectory-multisite rewrite rules
needed for subsite `/site-slug/wp-admin`, `/site-slug/wp-content/...` paths.
Subdomain multisite is not set up (`SUBDOMAIN_INSTALL` is hardcoded `false`
in `config/application.php`).

## Structure

- `nginx` serves `web/` (Bedrock's docroot) and proxies `.php` requests to
  `php` (PHP-FPM) — see `config/nginx.conf`. Both containers bind-mount the
  same project root, so no path translation between them.
- `web/app/themes/{slug}` and `web/app/plugins/{slug}` are git submodules —
  the *same path* in dev and in the deployed image. Since the whole project
  root is already bind-mounted (`.:/var/www/html`), editing files inside a
  submodule locally is instantly reflected — no extra mount entries needed.
- `web/wp/` (WP core) and `vendor/` are Composer-managed, not committed.
- One `Dockerfile` is used both by `docker-compose.yml` (dev — bind-mount
  overrides the `COPY`'d code for live edits) and by CI (prod — no
  bind-mount, so the built image is the immutable, self-contained deploy
  artifact).

## Deployment

Two kinds of pipeline, so app code and infra/deploy stay decoupled:

1. **App pipeline** — lives in each theme/plugin repo (
   `wolf-blocks`), not in this repo. On push, it lints, runs `npm run build`,
   then bumps this repo's submodule to the new commit:
   ```bash
   # run from the theme/plugin repo's own CI, after a successful build
   git clone git@github.com:wolfthemes/wolf-bedrock-docker.git
   cd wolf-bedrock-docker
   git submodule update --remote web/app/themes/wolf-blocks
   git commit -am "bump wolf-blocks to $(git -C web/app/themes/wolf-blocks rev-parse --short HEAD)"
   git push
   ```
   That push is what triggers deployment — each theme/plugin repo stays
   autonomous, and the orchestration logic lives only in this repo.

2. **Infra pipeline** (`.github/workflows/deploy.yml`, in this repo) — on
   push to `main`: checkout with `submodules: recursive` (latest bumped
   commit), `docker build` (bakes `composer install --no-dev` for WP core +
   third-party deps, versions pinned in `composer.lock`, plus all submodules
   at their pinned commit — this is the single `Dockerfile`), push the image
   to a registry, then SSH + `docker compose pull && up -d` on the remote.

A direct push to this repo (e.g. a `composer.json` bump) skips step 1 and
triggers step 2 directly.

This is Option A of two considered (the other being a `repository_dispatch`
event from each submodule into a single centrally-triggered CI) — chosen for
being simpler to reason about and debug when starting out. Each submodule can
still run its own lint/test CI independently; the Docker image built here
stays the single deployed artifact either way.
