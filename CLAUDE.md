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
  - `publications.html` (plural, list page) extends `default` — reads from `_data/bibliography.yml`
  - `publication.html` (singular, detail page) extends `default` — used by `_publications/` collection entries
- `_includes/nav.html` - Bilingual navigation component
- `_data/i18n.yml` - Bilingual labels keyed by `ja` / `en` (accessed via `site.data.i18n[page.lang]`)
- `_data/news.yml` - News items with `date`, `text_ja`, `text_en` fields
- `_data/bibliography.yml` - **Single source of truth for the publications list page**
- `_publications/` - Optional Markdown files for per-paper detail pages (Jekyll collection, rendered at `/projects/:name/`)

### Bilingual System
- Japanese pages: `index.html`, `publications.html`, `news.html`
- English pages: suffix `-e.html` (e.g., `index-e.html`, `publications-e.html`)
- Templates use `page.lang` variable for conditional content:
  ```liquid
  {% if page.lang == 'en' %}English{% else %}日本語{% endif %}
  ```

### Publications — Data Flow

The publications page has two concerns, handled by two different files:

**1. The list page (`publications.html` / `publications-e.html`)**

Driven entirely by `_data/bibliography.yml`. The `publications` layout reads this
file, splits entries by `type`, and renders three sections (§02.1 Journal,
§02.2 Conference, §02.3 Domestic). To add or edit an entry on the list page,
edit `_data/bibliography.yml` only — no layout or page changes are needed.

Entry schema:
```yaml
- title: "Paper Title"
  authors: "Author Names"
  venue: "Journal or Conference Name"
  year: 2025
  type: journal       # journal | conference | domestic
  url: "/projects/sample-paper/"   # optional: link target for the title
```

New entries should be added to the top of each category (the list is rendered
in insertion order with `<ol reversed>`, so the first entry gets the highest number).

**2. Per-paper detail pages (optional)**

If a paper needs a dedicated detail page (abstract, BibTeX, links), create a
Markdown file in `_publications/` with YAML front matter:
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
Jekyll renders this at `/projects/:name/`. To link the list entry to the detail
page, set `url: "/projects/:name/"` in the matching `bibliography.yml` entry.
The `_publications/` collection is optional — entries in `bibliography.yml`
without a `url` simply render as non-linked items.

### URL Generation
Always use Liquid filters for URLs:
```liquid
{{ '/index.html' | relative_url }}
{{ '/style.css' | relative_url }}
```

## Key Configuration

- `_config.yml`: Site settings, collection definitions, permalink patterns
- `baseurl: ""` - User site is served at the domain root, so no subpath prefix
