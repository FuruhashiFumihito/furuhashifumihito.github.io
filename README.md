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
- 日本語ページ: `index.html`, `publications.html`, `diary.html`
- 英語ページ: `-e.html` サフィックス（例: `index-e.html`, `publications-e.html`）

### データ・コンテンツ
- `_data/diary.yml` - 日記エントリ（日々のメモ。`date`, `text_ja`, `text_en` フィールド）
- `publications.bib` - 研究業績の BibTeX 単一情報源（一覧ページと個別ページの両方を駆動）
- `_publications/<bibtex_key>/` - 論文ごとのサイドカーフォルダ（1論文=1フォルダ）。
  `meta.yml`（graphical abstract / 図のメタ）、任意の `body_ja.md` / `body_en.md`（本文）、
  画像ファイルを同居させる。`_plugins/bibtex_publications.rb` が読み込んで
  `/projects/<bibtex_key>/` に合成する。
- `_plugins/bibtex_publications.rb` - 上記を処理するビルド時プラグイン

### 設定ファイル
- `_config.yml` - サイト設定（コレクションは未定義。プラグインが仮想ページを生成）
- `CLAUDE.md` - Claude Code向けのプロジェクトガイダンス

## バイリンガル機能

テンプレートで `page.lang` 変数を使用して言語別コンテンツを切り替え:
```liquid
{% if page.lang == 'en' %}English{% else %}日本語{% endif %}
```

## 研究業績の追加

1. `publications.bib` に BibTeX エントリを追記:
   ```bibtex
   @inproceedings{furuhashi2025example,
     author    = {Furuhashi, Fumihito},
     title     = {Example Paper Title},
     booktitle = {Example Conference},
     year      = {2025},
     doi       = {10.xxxx/yyyy}
   }
   ```
2. 一覧と詳細ページは自動生成されます（詳細ページは `/projects/<bibtex_key>/`）。
3. 詳細ページに graphical abstract や図、本文を追加したい場合は
   `_publications/<bibtex_key>/` フォルダを作成し、以下のファイルを配置:
   ```
   _publications/furuhashi2025example/
     meta.yml                # graphical_abstract / figures
     body_ja.md              # 任意: 日本語本文 (Notes セクション)
     body_en.md              # 任意: 英語本文
     graphical-abstract.png  # 画像ファイルは同フォルダに置く
     fig1.png
   ```
   `meta.yml` の `src:` は同フォルダ内のファイル名を直接書けます（プラグインが
   `/projects/<bibtex_key>/<filename>` に自動解決）。詳しくは `CLAUDE.md` を参照。

## GitHub Pagesでのデプロイ

ユーザーサイト（`furuhashifumihito.github.io`）として配信しています。
`main` ブランチへの push をトリガーに GitHub Actions (`.github/workflows/pages.yml`) が
Jekyll 4 でビルドし、`actions/deploy-pages` で Pages に公開します。

Settings → Pages → Source は **GitHub Actions** に設定されています。
