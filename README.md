# FHIR Blog

Markdown documentation published to GitHub Pages using Jekyll.

**Live site:** https://kasra321.github.io/FHIR_Blog/

## Quick Start

```bash
# First-time setup (initializes git repo and scaffold files)
./publish.sh --init-only

# Publish to GitHub Pages
./publish.sh
```

## Adding Content

1. Create a new `.md` file in the `docs/` folder:

   ```markdown
   ---
   layout: page
   title: My New Page
   ---

   Your content here.
   ```

2. Publish:

   ```bash
   ./publish.sh --message="Add new page"
   ```

The page will be live at `https://kasra321.github.io/FHIR_Blog/<filename>/` after GitHub Pages rebuilds (usually under a minute).

## Auto-generated Index

Each time `publish.sh` runs, it scans `docs/` for `.md` files (excluding `index.md`) and regenerates `docs/index.md` with an alphabetically sorted list of links. If a page has a `title:` in its YAML front matter, that title is used; otherwise a display name is derived from the filename.

## publish.sh Options

| Flag | Description |
|------|-------------|
| `--help` | Show usage information |
| `--dir=<path>` | Override docs directory (default: `docs`) |
| `--message=<msg>` | Custom commit message (default: `"Publish site updates"`) |
| `--init-only` | Initialize scaffold without committing or pushing |
| `--check-pages` | Check GitHub Pages deployment status after pushing (requires `gh` CLI) |

## One-Time GitHub Setup

After your first push, enable GitHub Pages in the repo settings:

1. Go to https://github.com/kasra321/FHIR_Blog/settings/pages
2. Under **Source**, select **Deploy from a branch**
3. Set branch to `main` and folder to `/docs`
4. Click **Save**

The site will be available within a few minutes.
