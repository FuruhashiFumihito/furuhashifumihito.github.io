require "bibtex"

# _bibliography/references.bib を読み込み、
# site.data.bibliography (配列) として公開する Jekyll Generator。
#
# 既存の _layouts/publications.html が参照する形
#   { title, authors, venue, year, type, url }
# に正規化して流し込む。layout 側の変更は不要。
module Jekyll
  class BibliographyGenerator < Generator
    safe true
    priority :high

    BIB_PATH = File.join("_bibliography", "references.bib").freeze

    # BibTeX エントリ種別 → 既定カテゴリ
    # エントリに `category = {...}` があればそちらを優先する
    TYPE_MAP = {
      article:       "journal",
      inbook:        "journal",
      incollection:  "journal",
      inproceedings: "conference",
      conference:    "conference",
      proceedings:   "conference",
      misc:          "domestic",
      techreport:    "domestic",
      unpublished:   "domestic",
    }.freeze

    def generate(site)
      path = File.join(site.source, BIB_PATH)

      unless File.exist?(path)
        Jekyll.logger.warn "Bibliography:", "#{BIB_PATH} が見つかりません (空の一覧を生成)"
        site.data["bibliography"] = []
        return
      end

      bib = BibTeX.open(path)

      entries = bib.select(&:entry?).map { |entry| normalize(entry) }

      # 新しい年ほど先頭に (同年内はファイル登録順を維持)
      entries = entries.each_with_index
                       .sort_by { |e, i| [-(e["year"] || 0), i] }
                       .map(&:first)

      site.data["bibliography"] = entries
      Jekyll.logger.info "Bibliography:", "#{entries.size} 件のエントリを #{BIB_PATH} から読み込みました"
    rescue StandardError => e
      Jekyll.logger.error "Bibliography:", "#{BIB_PATH} の解析に失敗: #{e.message}"
      site.data["bibliography"] = []
    end

    private

    def normalize(entry)
      {
        "title"   => clean(entry["title"]),
        "authors" => authors_for(entry),
        "venue"   => venue_for(entry),
        "year"    => year_for(entry),
        "type"    => category_for(entry),
        "url"     => entry.field?("url") ? clean(entry["url"]) : nil,
      }.compact
    end

    def clean(value)
      return nil if value.nil?
      value.to_s.gsub(/[{}]/, "").strip
    end

    def authors_for(entry)
      return nil unless entry.field?("author")
      entry["author"].to_s.gsub(/\s+and\s+/, ", ").gsub(/[{}]/, "").strip
    end

    def venue_for(entry)
      %w[venue journal booktitle howpublished].each do |field|
        return clean(entry[field]) if entry.field?(field)
      end
      nil
    end

    def year_for(entry)
      return nil unless entry.field?("year")
      entry["year"].to_s.to_i
    end

    def category_for(entry)
      if entry.field?("category")
        clean(entry["category"])
      else
        TYPE_MAP[entry.type] || "domestic"
      end
    end
  end
end
