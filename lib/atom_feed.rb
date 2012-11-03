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
        feed.title   "john pignata"
        feed.updated articles.first.date.to_time.iso8601
        feed.id      "http://feeds.feedburner.com/jpignata"
        feed.link    href: "http://tx.pignata.com", type: "text/html", rel: "alternate"
        feed.link    href: "http://tx.pignata.com/index.atom", type: "application/atom+xml", rel: "self"

        articles.each do |article|
          feed.entry do |entry|
            url = "http://tx.pignata.com" + article.permalink

            entry.id        url
            entry.published article.date.to_time.iso8601
            entry.updated   article.date.to_time.iso8601
            entry.link      href: url, type: "text/html", rel: "alternate"
            entry.title     article.title
            entry.summary   article.summary

            entry.author do |author|
              author.name "John Pignata"
            end

            entry.content(type: "html") do |content|
              content.cdata article.content
            end
          end
        end
      end
    end
  end

  def document_attributes
    {
      "xmlns"    => "http://www.w3.org/2005/Atom",
      "xml:lang" => "en-US",
      "xml:base" => "http://tx.pignata.com"
    }
  end
end
