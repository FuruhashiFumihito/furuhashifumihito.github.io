# Research Homepage

古橋郁一の研究用ホームページ（東京大学大学院生）
Jekyll-based bilingual (Japanese/English) academic research homepage

🌐 **Public URL**: https://furuhashifumihito.github.io/

## プロジェクト概要

Jekyllを使用したバイリンガル（日本語/英語）の学術研究用ホームページです。GitHub Pagesで公開されています。

## セットアップ

### 依存関係のインストール
```bash
bundle install
```

### ローカル開発サーバー
```bash
bundle exec jekyll serve
```
ローカルサーバーが起動します: http://localhost:4000

### 静的サイトのビルド
```bash
bundle exec jekyll build
```
`_site/` ディレクトリに静的ファイルが生成されます。

## ファイル構成

### レイアウト・テンプレート
- `_layouts/` - テンプレート階層
  - `default.html` - ベーステンプレート
  - `publication.html` - 研究業績ページ用テンプレート
- `_includes/nav.html` - バイリンガルナビゲーションコンポーネント

### ページ構成（バイリンガル）
- 日本語ページ: `index.html`, `publications.html`, `news.html`
- 英語ページ: `-e.html` サフィックス（例: `index-e.html`, `publications-e.html`）

### データ・コンテンツ
- `_data/news.yml` - ニュース項目（`text` と `text_en` フィールド）
- `_publications/` - 研究業績のMarkdownファイル（Jekyllコレクション）

### 設定ファイル
- `_config.yml` - サイト設定、コレクション定義、パーマリンクパターン
- `CLAUDE.md` - Claude Code向けのプロジェクトガイダンス

## バイリンガル機能

テンプレートで `page.lang` 変数を使用して言語別コンテンツを切り替え:
```liquid
{% if page.lang == 'en' %}English{% else %}日本語{% endif %}
```

## 研究業績の追加

`_publications/` ディレクトリに以下のYAMLフロントマターを持つMarkdownファイルを作成:
```yaml
---
layout: publication
title: "論文タイトル"
authors: "著者名"
venue: "学会名/ジャーナル名"
year: 2024
type: conference  # journal, conference, or domestic
links:
  paper: "URL"
  pdf: "URL"
  github: "URL"
abstract: "概要"
bibtex: |
  @inproceedings{...}
---
```

Jekyllが自動的に `/projects/:name/` にページを生成します。

## GitHub Pagesでのデプロイ

ユーザーサイト（`furuhashifumihito.github.io`）として配信しています。
`main` ブランチへの push をトリガーに GitHub Actions (`.github/workflows/pages.yml`) が
Jekyll 4 でビルドし、`actions/deploy-pages` で Pages に公開します。

Settings → Pages → Source は **GitHub Actions** に設定されています。
