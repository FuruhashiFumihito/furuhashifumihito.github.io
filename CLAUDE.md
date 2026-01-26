# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jekyll-based bilingual (Japanese/English) academic research homepage for a University of Tokyo graduate student. Deploys to GitHub Pages at `https://furuhashifumihito.github.io/homepage`.

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
- `_layouts/` - Template hierarchy: `default.html` (base) → `publication.html` (extends default)
- `_includes/nav.html` - Bilingual navigation component
- `_data/news.yml` - News items with `text` and `text_en` fields
- `_publications/` - Markdown files for publications/projects (Jekyll collection)

### Bilingual System
- Japanese pages: `index.html`, `publications.html`, `news.html`
- English pages: suffix `-e.html` (e.g., `index-e.html`, `publications-e.html`)
- Templates use `page.lang` variable for conditional content:
  ```liquid
  {% if page.lang == 'en' %}English{% else %}日本語{% endif %}
  ```

### Publication Collection
Publications are markdown files in `_publications/` with YAML front matter:
```yaml
---
layout: publication
title: "Paper Title"
authors: "Author Names"
venue: "Conference/Journal Name"
year: 2024
type: conference  # journal, conference, or domestic
links:
  paper: "URL"
  pdf: "URL"
  github: "URL"
abstract: "Abstract text"
bibtex: |
  @inproceedings{...}
---
```
Jekyll generates pages at `/projects/:name/` automatically.

### URL Generation
Always use Liquid filters for URLs:
```liquid
{{ '/index.html' | relative_url }}
{{ '/style.css' | relative_url }}
```

## Key Configuration

- `_config.yml`: Site settings, collection definitions, permalink patterns
- `baseurl: /homepage` - Required for GitHub Pages subdirectory deployment
