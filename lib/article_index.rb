require "psych"

class ArticleIndex
  class << self
    attr_writer :instance

    def instance
      @instance ||= begin
        attributes = IndexFile.new.articles
        articles   = Article.inflate(attributes)

        new(articles)
      end
    end
  end

  def initialize(articles)
    @articles = articles.sort
  end

  def all
    articles
  end

  def published
    articles.select(&:published?)
  end

  def latest
    published.first
  end

  def draft
    articles.detect { |article| !article.published? }
  end

  def find_by_permalink(permalink)
    permalink_index[permalink]
  end

  private

  attr_reader :articles

  def permalink_index
    @permalink_index ||= articles.each_with_object({}).each do |article, index|
      index[article.permalink] = article
    end
  end
end
