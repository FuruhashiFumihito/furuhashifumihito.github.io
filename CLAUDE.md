# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jekyll-based bilingual (Japanese/English) academic research homepage for a University of Tokyo graduate student. Deploys to GitHub Pages (user site) at `https://furuhashifumihito.github.io/` via the GitHub Actions workflow in `.github/workflows/pages.yml`.

## Build Commands

```bash
# Install dependencies
bundle install

# Local development server (http://localhost:4000)
bundle exec jekyll serve

# Build static site to _site/
bundle exec jekyll build
```

## Architecture

### Jekyll Structure
- `_layouts/` - Template hierarchy:
  - `default.html` (base)
  - `home.html` extends `default`
  - `publications.html` (plural, list page) extends `default` — renders `site.data.bibliography`
  - `publication.html` (singular, detail page) extends `default` — used by `_publications/` collection entries
- `_includes/nav.html` - Bilingual navigation component
- `_data/i18n.yml` - Bilingual labels keyed by `ja` / `en` (accessed via `site.data.i18n[page.lang]`)
- `_data/diary.yml` - Diary entries (daily memo style) with `date`, `text_ja`, `text_en` fields
- `_bibliography/references.bib` - **Single source of truth for the publications list page** (BibTeX)
- `_plugins/bibliography.rb` - Jekyll generator that parses the `.bib` at build time and exposes it as `site.data.bibliography`
- `_publications/` - Optional Markdown files for per-paper detail pages (Jekyll collection, rendered at `/projects/:name/`)

### Hero Banner Slideshow

The top banner on the home layout (`_layouts/home.html`) is an auto-advancing
slideshow driven by files placed in `assets/images/hero/`. To add or reorder
slides, just edit the folder contents — no template or config changes needed.

- **Supported extensions**: `.jpg`, `.jpeg`, `.png`, `.webp`
- **Order**: alphabetical by filename. Use a numeric prefix
  (`01-`, `02-`, ...) to control it.
- **Single image**: rendered statically (the rotation JS is a no-op).
- **Multiple images**: crossfade every 5 s (1 s fade). Respects
  `prefers-reduced-motion`.
- **Performance**: the first slide gets `loading="eager"` +
  `fetchpriority="high"` for LCP; the rest are `loading="lazy"`.

The slideshow is assembled at build time by Liquid iterating over
`site.static_files` filtered to `/assets/images/hero/`. Styling lives in
`style.css` under `.hero__banner` / `.hero__slide`; the rotation script is
inlined near the bottom of `_layouts/home.html`.

### Bilingual System
- Japanese pages: `index.html`, `publications.html`, `diary.html`
- English pages: suffix `-e.html` (e.g., `index-e.html`, `publications-e.html`)
- Templates use `page.lang` variable for conditional content:
  ```liquid
  {% if page.lang == 'en' %}English{% else %}日本語{% endif %}
  ```

### Publications — Data Flow

The publications page has two concerns, handled by two different files:

**1. The list page (`publications.html` / `publications-e.html`)**

Driven by `_bibliography/references.bib` (BibTeX). At build time,
`_plugins/bibliography.rb` parses the file with `bibtex-ruby` and populates
`site.data.bibliography` with the same array-of-hashes shape the layout
expects — so `_layouts/publications.html` needs no changes. Adding or
editing an entry on the list page is purely a matter of editing the `.bib`.

Each entry is normalized to:
```yaml
title:   "Paper Title"
authors: "Author Names"            # " and " → ", "
venue:   "..."                     # first of: venue / journal / booktitle / howpublished
year:    2025
type:    "journal"                 # journal | conference | domestic
url:     "/projects/sample-paper/" # optional
```

Category resolution (`type` field):
1. If the BibTeX entry has a `category = {journal|conference|domestic}`
   field, that value wins.
2. Otherwise, inferred from the BibTeX entry type via
   `TYPE_MAP` in `_plugins/bibliography.rb`:
   - `@article`, `@inbook`, `@incollection` → `journal`
   - `@inproceedings`, `@conference`, `@proceedings` → `conference`
   - `@misc`, `@techreport`, `@unpublished` → `domestic`

Use the `category` override when a BibTeX entry type doesn't match the
desired section — e.g., a domestic conference published as `@inproceedings`
that should appear under §02.3 Domestic.

Entries are sorted by year descending at build time; within a year, the order
in the `.bib` file is preserved. The list page renders with `<ol reversed>`.

**2. Per-paper detail pages (optional)**

If a paper needs a dedicated detail page (abstract, BibTeX block, links),
create a Markdown file in `_publications/` with YAML front matter:
```yaml
---
layout: publication
title: "Paper Title"
authors: "Author Names"
venue: "Conference/Journal Name"
year: 2024
type: conference
links:
  paper: "URL"
  pdf: "URL"
  github: "URL"
abstract: "Abstract text"
bibtex: |
  @inproceedings{...}
---
```
Jekyll renders this at `/projects/:name/`. To link the list entry to the
detail page, set `url = {/projects/:name/}` in the matching `.bib` entry.
The `_publications/` collection is optional — BibTeX entries without a `url`
field simply render as non-linked items on the list page.

### Adding a Publication

1. Append a BibTeX entry to `_bibliography/references.bib`.
2. (Optional) If the paper deserves a detail page, create
   `_publications/<slug>.md` and set `url = {/projects/<slug>/}` in the
   matching `.bib` entry.
3. `bundle exec jekyll serve` — the generator logs how many entries it
   loaded; verify the paper appears in the expected §02.x section.

### URL Generation
Always use Liquid filters for URLs:
```liquid
{{ '/index.html' | relative_url }}
{{ '/style.css' | relative_url }}
```

## Key Configuration

- `_config.yml`: Site settings, collection definitions, permalink patterns
- `baseurl: ""` - User site is served at the domain root, so no subpath prefix
