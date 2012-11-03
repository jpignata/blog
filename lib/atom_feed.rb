require "nokogiri"

class AtomFeed
  def initialize(articles)
    @articles = articles
  end

  def to_xml
    builder = build_document
    builder.to_xml
  end

  private

  attr_reader :articles

  def build_document
    @builder ||= Nokogiri::XML::Builder.new.tap do |builder|
      builder.feed(document_attributes) do |feed|
        feed.title   "john pignata :: tx.pignata.com"
        feed.updated articles.first.date.iso8601
        feed.id      "http://tx.pignata.com/index.atom"
        feed.link    href: "http://tx.pignata.com", type: "text/html", rel: "alternate"
        feed.link    href: "http://tx.pignata.com/index.atom", type: "application/atom+xml", rel: "self"

        articles.each do |article|
          feed.entry do |entry|
            url = "http://tx.pignata.com" + article.permalink

            entry.id        url
            entry.published article.date.iso8601
            entry.updated   article.date.iso8601
            entry.link      href: url, type: "text/html", rel: "alternate"
            entry.title     article.title
            entry.summary   article.summary

            entry.content(type: "html") { |content|
              content.cdata article.content
            }
          end
        end
      end
    end
  end

  def document_attributes
    {
      "xmlns"    => "http://www.w3.org/2005/Atom",
      "xml:lang" => "en-US"
    }
  end
end
