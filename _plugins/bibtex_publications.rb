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
#   3. `_publications/<bibtex_key>/` フォルダから論文ごとの追加コンテンツを
#      取り込む (graphical abstract / 図 / 本文 / 画像ファイル)。
#      1論文=1フォルダで管理できるようにする仕組み。
#
#      対応ファイル:
#        meta.yml      -- graphical_abstract / figures のメタデータ (任意)
#        body_ja.md    -- 日本語ページの本文 (Notes セクション)
#        body_en.md    -- 英語ページの本文
#        body.md       -- 言語共通フォールバック
#        *.png|jpg|... -- 画像ファイル (meta.yml から相対パスで参照可)
#
#      meta.yml 内の `src:` は相対パスで書くと /projects/<key>/<filename>
#      に自動解決される (同フォルダの画像を指しているとみなす)。
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

    SUPPORTED_CATEGORIES = %w[journal conference domestic other].freeze
    # サイドカーフォルダから /projects/<key>/ にコピーするファイル拡張子。
    # 画像に加え、補足資料の PDF も配信対象にする。
    SERVED_EXTS = %w[.png .jpg .jpeg .webp .gif .svg .pdf].freeze
    PUBLICATIONS_SRC_DIR = "_publications"

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

      # 各エントリの _publications/<bibtex_key>/ からサイドカー (meta.yml, body_*.md,
      # 画像) を読み込み、仮想ページに merge する。該当フォルダが無ければ
      # プレーンな詳細ページが生成される。
      # 併せて、一覧ページでも参照できるよう graphical_abstract だけは
      # site.data.bibliography のエントリ側にも書き戻す。
      normalized.each do |entry|
        sidecar = load_sidecar(site, entry)
        if sidecar.is_a?(Hash) && sidecar["overrides"].is_a?(Hash)
          ga = sidecar["overrides"]["graphical_abstract"]
          entry["graphical_abstract"] = ga if ga.is_a?(Hash) && ga["src"]
        end
        site.pages << PublicationPage.new(site, entry, sidecar)
      end
    end

    # ----- _publications/<key>/ 以下のサイドカー読み込み -----
    def load_sidecar(site, entry)
      key = entry["key"]
      dir = File.join(site.source, PUBLICATIONS_SRC_DIR, key)
      return nil unless File.directory?(dir)

      sidecar = { "overrides" => {}, "body" => {} }
      base_url = "/projects/#{entry['slug']}"

      # --- meta.yml ---
      meta_path = File.join(dir, "meta.yml")
      if File.exist?(meta_path)
        begin
          loaded = YAML.safe_load(File.read(meta_path, encoding: "UTF-8"), permitted_classes: [], aliases: false) || {}
          sidecar["overrides"] = resolve_meta_paths(loaded, base_url)
        rescue Psych::SyntaxError => e
          Jekyll.logger.warn "Bibtex:", "failed to parse #{meta_path}: #{e.message}"
        end
      end

      # --- body_ja.md / body_en.md / body.md ---
      %w[ja en].each do |lang|
        path = File.join(dir, "body_#{lang}.md")
        sidecar["body"][lang] = File.read(path, encoding: "UTF-8") if File.exist?(path)
      end
      fallback = File.join(dir, "body.md")
      sidecar["body"]["fallback"] = File.read(fallback, encoding: "UTF-8") if File.exist?(fallback)

      # --- 画像・PDF を StaticFile として登録 ---
      # SERVED_EXTS に該当するファイルは /projects/<key>/<filename> に配信される。
      Dir.foreach(dir) do |name|
        next if name.start_with?(".")
        next unless SERVED_EXTS.include?(File.extname(name).downcase)
        abs = File.join(dir, name)
        next unless File.file?(abs)
        site.static_files << PublicationStaticFile.new(
          site, site.source, "#{PUBLICATIONS_SRC_DIR}/#{key}", name, base_url
        )
      end

      sidecar
    end

    # meta.yml 内の `src` が相対パスのときだけ /projects/<key>/ に解決する。
    # 絶対パス (/で始まる) や外部URL (http...) はそのまま維持。
    def resolve_meta_paths(meta, base_url)
      meta = deep_dup(meta)

      if meta["graphical_abstract"].is_a?(Hash)
        meta["graphical_abstract"]["src"] = resolve_src(meta["graphical_abstract"]["src"], base_url)
      end

      if meta["figures"].is_a?(Array)
        meta["figures"].each do |fig|
          next unless fig.is_a?(Hash)
          fig["src"] = resolve_src(fig["src"], base_url)
        end
      end

      meta
    end

    def resolve_src(src, base_url)
      return src if src.nil? || src.empty?
      return src if src.start_with?("/", "http://", "https://")
      "#{base_url}/#{src}"
    end

    def deep_dup(obj)
      case obj
      when Hash  then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
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
    # sidecar: _publications/<key>/ から読み込んだ補足データ。
    #   { "overrides" => {...meta.yml...}, "body" => {"ja"=>..., "en"=>..., "fallback"=>...} }
    # nil なら何もマージしない。
    def initialize(site, entry, sidecar = nil)
      @site = site
      @base = site.source
      @dir  = "projects/#{entry['slug']}"
      @name = "index.html"

      process(@name)

      lang = entry["lang"] || "ja"

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
        "lang"      => lang,
        "permalink" => entry["url"],
      }

      body_markdown = ""

      if sidecar.is_a?(Hash)
        overrides = sidecar["overrides"]
        @data.merge!(overrides) if overrides.is_a?(Hash)

        body_src = sidecar["body"] || {}
        body_markdown = body_src[lang] || body_src["fallback"] || ""
      end

      # body_*.md を markdown -> HTML に変換して page.content に注入
      @content =
        if body_markdown && !body_markdown.strip.empty?
          site.find_converter_instance(::Jekyll::Converters::Markdown).convert(body_markdown)
        else
          ""
        end

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

  # ---------------------------------------------------------------
  # _publications/<key>/*.png などを /projects/<key>/<file> に出力する
  # ---------------------------------------------------------------
  class PublicationStaticFile < Jekyll::StaticFile
    def initialize(site, base, dir, name, dest_url)
      super(site, base, dir, name)
      @dest_url = dest_url
    end

    # 出力先を /projects/<slug>/<filename> に差し替える
    def destination_rel_dir
      @dest_url
    end

    def url
      "#{@dest_url}/#{@name}"
    end
  end
end
