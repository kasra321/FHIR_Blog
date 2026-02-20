#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
REMOTE_URL="https://github.com/kasra321/FHIR_Blog.git"
SITE_URL="https://kasra321.github.io/FHIR_Blog/"
DEFAULT_DOCS_DIR="docs"
DEFAULT_MESSAGE="Publish site updates"

# --- Color output ---
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

info()  { echo -e "${CYAN}[info]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[ok]${RESET}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${RESET}  $*"; }
err()   { echo -e "${RED}[error]${RESET} $*" >&2; }

# --- Defaults ---
DOCS_DIR="$DEFAULT_DOCS_DIR"
COMMIT_MSG="$DEFAULT_MESSAGE"
INIT_ONLY=false
CHECK_PAGES=false

# --- Argument parsing ---
usage() {
  cat <<EOF
Usage: ./publish.sh [OPTIONS]

Publish Markdown documentation to GitHub Pages via Jekyll.

Options:
  --help              Show this help message
  --dir=<path>        Override docs directory (default: docs)
  --message=<msg>     Custom commit message (default: "Publish site updates")
  --init-only         Only initialize scaffold; don't commit or push
  --check-pages       After pushing, check GitHub Pages deployment status

Examples:
  ./publish.sh --init-only          # First-time setup
  ./publish.sh --message="Add post" # Publish with custom message
  ./publish.sh --check-pages        # Publish and check deployment
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --help)          usage ;;
    --dir=*)         DOCS_DIR="${arg#--dir=}" ;;
    --message=*)     COMMIT_MSG="${arg#--message=}" ;;
    --init-only)     INIT_ONLY=true ;;
    --check-pages)   CHECK_PAGES=true ;;
    *)               err "Unknown option: $arg"; usage ;;
  esac
done

# --- Functions ---

ensure_git_repo() {
  if [[ ! -d .git ]]; then
    info "Initializing git repository..."
    git init -b main
    ok "Git repo initialized on branch main."
  fi

  # Ensure we're on main
  local branch
  branch=$(git branch --show-current 2>/dev/null || true)
  if [[ "$branch" != "main" ]]; then
    # Check if main exists
    if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
      git checkout main
    else
      git checkout -b main
    fi
    ok "Switched to branch main."
  fi

  # Ensure remote
  if ! git remote get-url origin &>/dev/null; then
    git remote add origin "$REMOTE_URL"
    ok "Remote origin set to $REMOTE_URL"
  else
    local current_url
    current_url=$(git remote get-url origin)
    if [[ "$current_url" != "$REMOTE_URL" ]]; then
      warn "Remote origin is $current_url (expected $REMOTE_URL)"
    fi
  fi
}

ensure_jekyll_scaffold() {
  local created=0

  mkdir -p "$DOCS_DIR"

  if [[ ! -f "$DOCS_DIR/_config.yml" ]]; then
    cat > "$DOCS_DIR/_config.yml" <<'YAML'
title: "FHIR Blog"
description: "FHIR documentation published with GitHub Pages"
theme: minima
baseurl: "/FHIR_Blog"
url: "https://kasra321.github.io"
markdown: kramdown
kramdown:
  input: GFM
exclude:
  - Gemfile
  - Gemfile.lock
  - README.md
YAML
    ((created++))
  fi

  if [[ ! -f "$DOCS_DIR/index.md" ]]; then
    cat > "$DOCS_DIR/index.md" <<'MD'
---
layout: home
title: Home
---

Welcome to the FHIR Blog.
MD
    ((created++))
  fi

  if [[ ! -f "$DOCS_DIR/Gemfile" ]]; then
    cat > "$DOCS_DIR/Gemfile" <<'RUBY'
source "https://rubygems.org"
gem "github-pages", group: :jekyll_plugins
RUBY
    ((created++))
  fi

  if [[ ! -f .gitignore ]]; then
    cat > .gitignore <<'GI'
docs/_site/
docs/.sass-cache/
docs/.jekyll-cache/
docs/.jekyll-metadata
docs/vendor/
docs/Gemfile.lock
.DS_Store
GI
    ((created++))
  fi

  if ((created > 0)); then
    ok "Created $created scaffold file(s) in $DOCS_DIR/"
  else
    ok "Scaffold already exists — nothing to create."
  fi
}

update_index() {
  local pages=()
  local file title name link

  while IFS= read -r -d '' file; do
    # Extract title from YAML front matter
    title=""
    if head -1 "$file" | grep -q '^---$'; then
      title=$(awk '/^---$/{n++; next} n==1 && /^title:/{sub(/^title:[[:space:]]*/, ""); gsub(/^["'\''"]|["'\''"]$/, ""); print; exit}' "$file")
    fi

    # Fallback: derive display name from filename
    if [[ -z "$title" ]]; then
      name=$(basename "$file" .md)
      # Replace - and _ with spaces, then title-case
      title=$(echo "$name" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    fi

    link=$(basename "$file" .md)
    pages+=("- [$title]($link)")
  done < <(find "$DOCS_DIR" -maxdepth 1 -name '*.md' ! -name 'index.md' -print0 | sort -z)

  if ((${#pages[@]} == 0)); then
    info "No content pages found — skipping index update."
    return
  fi

  # Sort entries alphabetically
  IFS=$'\n' sorted=($(printf '%s\n' "${pages[@]}" | sort)); unset IFS

  cat > "$DOCS_DIR/index.md" <<MD
---
layout: home
title: Home
---

Welcome to the FHIR Blog.

## Pages

$(printf '%s\n' "${sorted[@]}")
MD

  ok "Updated index.md with ${#sorted[@]} page link(s)."
}

publish() {
  git add -A

  if git diff --cached --quiet; then
    warn "Working tree is clean — nothing to commit."
    return 0
  fi

  git commit -m "$COMMIT_MSG"
  ok "Committed: $COMMIT_MSG"

  info "Pushing to origin/main..."
  git push -u origin main
  ok "Pushed to origin/main."
}

check_pages() {
  if ! command -v gh &>/dev/null; then
    warn "'gh' CLI not found. Install it to check Pages status automatically."
    echo ""
    echo "Manual setup: go to $REMOTE_URL → Settings → Pages"
    echo "  Source: Deploy from a branch → Branch: main → Folder: /docs → Save"
    return
  fi

  info "Checking GitHub Pages status..."
  local response
  response=$(gh api "repos/kasra321/FHIR_Blog/pages" 2>&1) || {
    warn "GitHub Pages is not enabled yet."
    echo ""
    echo "Enable it at: https://github.com/kasra321/FHIR_Blog/settings/pages"
    echo "  Source: Deploy from a branch"
    echo "  Branch: main"
    echo "  Folder: /docs"
    echo "  Click Save"
    return
  }

  local status
  status=$(echo "$response" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [[ -n "$status" ]]; then
    info "Pages status: $status"
  fi
  ok "Site URL: $SITE_URL"
}

# --- Main ---

info "Working directory: $(pwd)"
info "Docs directory: $DOCS_DIR"
echo ""

ensure_git_repo
ensure_jekyll_scaffold
update_index

if $INIT_ONLY; then
  echo ""
  ok "Initialization complete. Run ./publish.sh to commit and push."
  exit 0
fi

echo ""
publish

if $CHECK_PAGES; then
  echo ""
  check_pages
fi

echo ""
ok "Done! Site will be available at: $SITE_URL"
echo "  (Make sure GitHub Pages is enabled — see ./publish.sh --help)"
