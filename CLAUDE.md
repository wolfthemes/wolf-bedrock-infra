# CLAUDE.md

Guidance for working in this workspace.

## ⚠️ Multiple independent Git repositories

Like its sibling `wolf-store-docker`, this is **not a monorepo**. The root is
one Git repo (the Docker dev env + Bedrock skeleton); `web/app/themes/*` and
`web/app/plugins/*` are git submodules — separate, independent repos tracked
at a pinned commit, not plain clones.

### Rules when working across projects

- **Never assume a commit in one repo affects another.** A change is only
  staged, committed, branched, or pushed in the single repo it lives in.
  Bumping a submodule pointer in this repo is itself a commit here, distinct
  from any commit inside the submodule's own repo.
- **Git commands apply only to the repo you are currently inside.** Prefer
  `git -C <path> ...` to target a specific repo explicitly.
- Check remotes/branches before committing: `git -C <path> remote -v`.

## Project context

Local Bedrock (Roots) WordPress dev environment run via Docker: `nginx` +
PHP-FPM (`php` service) + MySQL. Bedrock's docroot is `web/` — handled by
`config/nginx.conf` (`root /var/www/html/web`), not by rewriting the PHP
container. WP core (`web/wp/`) and `vendor/` are installed via Composer, not
committed. See `README.md` for setup, daily workflow, and the deploy
pipeline (submodule bump → image build → push → remote deploy).
