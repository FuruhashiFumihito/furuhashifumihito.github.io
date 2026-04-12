require "bibtex"

# 受賞歴 (award.bib) と研究助成 (grants.bib) をビルド時に読み込み、
# 以下の配列として `site.data` に公開する Jekyll Generator。
#
#   site.data["awards"]  <- award.bib
#   site.data["grants"]  <- grants.bib
#
# それぞれのエントリは `_plugins/bibliography.rb` と同じ正規化形
#   { title, authors, venue, year, note, url }
# に揃えてあるので、`_layouts/bib_list.html` から `page.bib_source`
# で差し替えるだけで同じレイアウトが使い回せる。
module Jekyll
  class BibtexExtrasGenerator < Generator
    safe true
    priority :high

    # site.data のキー => プロジェクトルートからの相対パス
    SOURCES = {
      "awards" => "award.bib",
      "grants" => "grants.bib",
    }.freeze

    def generate(site)
      SOURCES.each do |key, rel_path|
        site.data[key] = load_bib(site, rel_path)
      end
    end

    private

    def load_bib(site, rel_path)
      path = File.join(site.source, rel_path)

      unless File.exist?(path)
        Jekyll.logger.warn "BibtexExtras:", "#{rel_path} が見つかりません (空の一覧を生成)"
        return []
      end

      bib = BibTeX.open(path)
      entries = bib.select(&:entry?).map { |entry| normalize(entry) }

      # 新しい年ほど先頭に (同年内はファイル登録順を維持)
      sorted = entries.each_with_index
                      .sort_by { |e, i| [-(e["year"] || 0), i] }
                      .map(&:first)

      Jekyll.logger.info "BibtexExtras:", "#{sorted.size} 件のエントリを #{rel_path} から読み込みました"
      sorted
    rescue StandardError => e
      Jekyll.logger.error "BibtexExtras:", "#{rel_path} の解析に失敗: #{e.message}"
      []
    end

    def normalize(entry)
      {
        "title"   => clean(entry["title"]),
        "authors" => authors_for(entry),
        "venue"   => venue_for(entry),
        "year"    => year_for(entry),
        "note"    => entry.field?("note") ? clean(entry["note"]) : nil,
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
      %w[venue journal booktitle howpublished school institution].each do |field|
        return clean(entry[field]) if entry.field?(field)
      end
      nil
    end

    def year_for(entry)
      return nil unless entry.field?("year")
      entry["year"].to_s.to_i
    end
  end
end
