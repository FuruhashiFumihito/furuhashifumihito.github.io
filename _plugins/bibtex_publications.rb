# frozen_string_literal: true
#
# _plugins/bibtex_publications.rb
#
# publications.bib をパースして以下を行うJekyll Generator:
#
#   1. site.data["bibliography"] に正規化済みの業績一覧を投入
#      (publications.html レイアウトが参照)
#
#   2. 各エントリについて /projects/<key>/ に仮想ページを生成
#      (publication レイアウトで詳細表示)
#
# このプラグインは GitHub Actions のカスタムワークフロー (.github/workflows/pages.yml)
# を前提としており、素のGitHub Pagesサンドボックスでは動作しない点に注意。
#
# 対応BibTeX種別:
#   @article       -> type: "journal"
#   @inproceedings -> type: "conference"
#   @conference    -> type: "conference"
#   @misc          -> type: "domestic"
#   @techreport    -> type: "domestic"
#   その他         -> type: "domestic"
#
# フィールドの拡張 (BibTeX標準にない独自フィールド):
#   bib_category = {journal|conference|domestic}  -- 種別を手動で上書き
#   lang         = {ja|en}                        -- 言語 (既定: ja)
#   pdf          = {URL}                          -- PDFへのリンク
#   github       = {URL}                          -- GitHub
#   slides       = {URL}                          -- スライド
#   video        = {URL}                          -- 動画
#

module Jekyll
  class BibtexPublicationsGenerator < Generator
    safe true
    priority :high

    SUPPORTED_CATEGORIES = %w[journal conference domestic].freeze

    def generate(site)
      bib_path = File.join(site.source, "publications.bib")
      unless File.exist?(bib_path)
        Jekyll.logger.warn "Bibtex:", "publications.bib not found — skipping"
        return
      end

      raw = File.read(bib_path, encoding: "UTF-8")
      entries = BibTeXParser.parse(raw)
      normalized = entries.map { |e| normalize(e) }.compact

      # 新しい順 (同年は元の登場順を維持)
      normalized = normalized.sort_by.with_index { |e, i| [-(e["year"] || 0), i] }

      site.data["bibliography"] = normalized

      Jekyll.logger.info "Bibtex:", "loaded #{normalized.size} entries from publications.bib"

      # 図・graphical abstract のサイドカー (_data/publication_figures.yml)。
      # 各エントリの BibTeX キーで引いて仮想ページに merge する。
      figures_data = site.data["publication_figures"] || {}

      normalized.each do |entry|
        overrides = figures_data[entry["key"]]
        site.pages << PublicationPage.new(site, entry, overrides)
      end
    end

    # ----- BibTeXエントリ -> Jekyllが食べやすい形に正規化 -----
    def normalize(raw)
      return nil unless raw[:title] && raw[:key]

      slug = slugify(raw[:key])

      category = pick_category(raw)

      authors = format_authors(raw[:author])
      venue   = clean(raw[:journal] || raw[:booktitle] || raw[:howpublished] || raw[:school] || raw[:institution])

      links = {}
      if raw[:doi] && !raw[:doi].empty?
        links["paper"] = raw[:doi].start_with?("http") ? raw[:doi] : "https://doi.org/#{raw[:doi]}"
      elsif raw[:url] && !raw[:url].empty?
        links["paper"] = raw[:url]
      end
      links["pdf"]    = raw[:pdf]    if raw[:pdf]    && !raw[:pdf].empty?
      links["github"] = raw[:github] if raw[:github] && !raw[:github].empty?
      links["slides"] = raw[:slides] if raw[:slides] && !raw[:slides].empty?
      links["video"]  = raw[:video]  if raw[:video]  && !raw[:video].empty?

      {
        "slug"     => slug,
        "key"      => raw[:key],
        "title"    => clean(raw[:title]),
        "authors"  => authors,
        "venue"    => venue,
        "year"     => (raw[:year] || "").to_s.to_i,
        "type"     => category,
        "links"    => links.empty? ? nil : links,
        "abstract" => clean(raw[:abstract]),
        "bibtex"   => render_bibtex(raw),
        "lang"     => (raw[:lang] || "ja").to_s,
        "url"      => "/projects/#{slug}/",
      }
    end

    def pick_category(raw)
      # 明示的な bib_category フィールドが最優先
      if raw[:bib_category] && SUPPORTED_CATEGORIES.include?(raw[:bib_category])
        return raw[:bib_category]
      end

      case raw[:entry_type]
      when "article"                              then "journal"
      when "inproceedings", "conference"          then "conference"
      when "misc", "techreport", "unpublished"    then "domestic"
      else                                              "domestic"
      end
    end

    def format_authors(raw)
      return nil unless raw
      s = clean(raw)
      return s unless s

      # BibTeX標準の "and" 区切り形式の場合のみ "Last, First" を "First Last" に反転
      if s =~ /\s+and\s+/
        s.split(/\s+and\s+/).map do |name|
          if name.include?(",")
            last, first = name.split(",", 2)
            "#{first.strip} #{last.strip}"
          else
            name.strip
          end
        end.join(", ")
      else
        # 既に日本語などでカンマ区切りになっているケースはそのまま
        s
      end
    end

    def clean(value)
      return nil unless value
      value.to_s.gsub(/[{}]/, "").strip.squeeze(" ").then { |s| s.empty? ? nil : s }
    end

    def slugify(key)
      key.to_s.downcase.gsub(/[^a-z0-9_-]+/, "-").gsub(/^-+|-+$/, "")
    end

    # 詳細ページで表示する整形済みBibTeX文字列を組み立て
    def render_bibtex(raw)
      omitted = %i[entry_type key bib_category lang pdf github slides video]
      fields  = raw.reject { |k, _| omitted.include?(k) }
      width   = fields.keys.map { |k| k.to_s.length }.max || 1
      lines   = fields.map { |k, v| "  #{k.to_s.ljust(width)} = {#{v}}" }
      "@#{raw[:entry_type]}{#{raw[:key]},\n#{lines.join(",\n")}\n}"
    end
  end

  # ---------------------------------------------------------------
  # ハンドローラーのBibTeXパーサ
  # ---------------------------------------------------------------
  #
  # 基本的な @type{key, field = {value}, ... } 構造を処理。
  # ネストした波括弧、"..."形式の文字列リテラル、
  # 行頭コメント (%)、複数行にわたる値にも対応する。
  class BibTeXParser
    def self.parse(src)
      new(src).parse
    end

    def initialize(src)
      @src = src
      @len = src.length
      @pos = 0
    end

    def parse
      entries = []
      while @pos < @len
        skip_whitespace_and_comments
        break if @pos >= @len
        if @src[@pos] == "@"
          entry = read_entry
          entries << entry if entry
        else
          @pos += 1
        end
      end
      entries
    end

    private

    def skip_whitespace_and_comments
      while @pos < @len
        c = @src[@pos]
        if c =~ /\s/
          @pos += 1
        elsif c == "%"
          @pos += 1 while @pos < @len && @src[@pos] != "\n"
        else
          break
        end
      end
    end

    def read_entry
      @pos += 1 # consume @

      # エントリタイプを読む
      type_start = @pos
      @pos += 1 while @pos < @len && @src[@pos] =~ /[A-Za-z]/
      type = @src[type_start...@pos].downcase
      return nil if type.empty?

      # コメント等のメタ的な擬似エントリはスキップ
      return nil if %w[comment preamble string].include?(type)

      skip_whitespace_and_comments
      return nil unless @src[@pos] == "{"
      @pos += 1

      skip_whitespace_and_comments

      # エントリキーを読む (次のカンマまで)
      key_start = @pos
      @pos += 1 while @pos < @len && @src[@pos] !~ /[,\s}]/
      key = @src[key_start...@pos]
      return nil if key.empty?

      skip_whitespace_and_comments
      @pos += 1 if @pos < @len && @src[@pos] == ","

      fields = { entry_type: type, key: key }

      loop do
        skip_whitespace_and_comments
        break if @pos >= @len || @src[@pos] == "}"

        # フィールド名を読む
        name_start = @pos
        @pos += 1 while @pos < @len && @src[@pos] =~ /[A-Za-z0-9_-]/
        name = @src[name_start...@pos].downcase
        break if name.empty?

        skip_whitespace_and_comments
        unless @pos < @len && @src[@pos] == "="
          # 壊れたフィールド — エントリを諦めて終端まで飛ばす
          advance_to_entry_end
          break
        end
        @pos += 1
        skip_whitespace_and_comments

        value = read_value
        fields[name.to_sym] = value if value

        skip_whitespace_and_comments
        if @pos < @len && @src[@pos] == ","
          @pos += 1
        end
      end

      @pos += 1 if @pos < @len && @src[@pos] == "}"
      fields
    end

    def read_value
      return nil if @pos >= @len
      c = @src[@pos]

      if c == "{"
        read_braced
      elsif c == '"'
        read_quoted
      else
        read_bare
      end
    end

    def read_braced
      @pos += 1 # consume opening {
      buf = +""
      depth = 1
      while @pos < @len && depth > 0
        c = @src[@pos]
        if c == "{"
          depth += 1
          buf << c
        elsif c == "}"
          depth -= 1
          buf << c if depth > 0
        else
          buf << c
        end
        @pos += 1
      end
      normalize_value(buf)
    end

    def read_quoted
      @pos += 1 # consume opening "
      buf = +""
      while @pos < @len
        c = @src[@pos]
        break if c == '"'
        buf << c
        @pos += 1
      end
      @pos += 1 if @pos < @len # consume closing "
      normalize_value(buf)
    end

    def read_bare
      buf = +""
      while @pos < @len && @src[@pos] =~ /[\w\-]/
        buf << @src[@pos]
        @pos += 1
      end
      normalize_value(buf)
    end

    def normalize_value(str)
      str.to_s.strip.gsub(/\s+/, " ")
    end

    # 壊れたエントリ回復用: 次の@エントリまでスキップ
    def advance_to_entry_end
      depth = 1
      while @pos < @len && depth > 0
        c = @src[@pos]
        depth += 1 if c == "{"
        depth -= 1 if c == "}"
        @pos += 1
      end
    end
  end

  # ---------------------------------------------------------------
  # 仮想ページ (ディスク上にファイルが無い Jekyll::Page)
  # ---------------------------------------------------------------
  class PublicationPage < Jekyll::Page
    # overrides: _data/publication_figures.yml で当該キーに紐付く追加データ
    # (graphical_abstract, figures など)。nil なら何もマージしない。
    def initialize(site, entry, overrides = nil)
      @site = site
      @base = site.source
      @dir  = "projects/#{entry['slug']}"
      @name = "index.html"

      process(@name)

      @data = {
        "layout"    => "publication",
        "title"     => entry["title"],
        "authors"   => entry["authors"],
        "venue"     => entry["venue"],
        "year"      => entry["year"],
        "type"      => entry["type"],
        "links"     => entry["links"],
        "abstract"  => entry["abstract"],
        "bibtex"    => entry["bibtex"],
        "lang"      => entry["lang"] || "ja",
        "permalink" => entry["url"],
      }

      if overrides.is_a?(Hash)
        @data.merge!(overrides)
      end

      @content = ""

      data.default_proc = proc do |_, key|
        site.frontmatter_defaults.find(relative_path, type, key)
      end

      Jekyll::Hooks.trigger :pages, :post_init, self
    end

    # 仮想ページなので物理ファイルからYAMLを読まない
    def read_yaml(*)
      @data ||= {}
    end
  end
end
