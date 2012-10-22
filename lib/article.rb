class Article
  DEFAULT_FILE_DIRECTORY = "articles"

  attr_accessor :title, :date, :summary, :permalink, :file_name

  def self.inflate(articles_attributes, options={})
    articles_attributes.map { |article_attributes|
      new(article_attributes, options)
    }
  end

  def initialize(attributes={}, options={})
    @date        = attributes["date"]
    @title       = attributes["title"]
    @summary     = attributes["summary"]
    @file_name   = attributes["file_name"]
    @permalink   = attributes.fetch("permalink") { default_permalink }

    @file_parser    = options.fetch(:file_parser) { ContentFile }
    @file_directory = options.fetch(:file_directory) { DEFAULT_FILE_DIRECTORY }
  end

  def <=>(other)
    other.date <=> date
  end

  def content
    @content ||= file_parser.new("#{@file_directory}/#{file_name}").content
  end

  private

  attr_reader :file_parser

  def default_permalink
    [year, month, slug].compact.join("/").prepend("/") + ".html"
  end

  def month
    date && date.strftime("%m")
  end

  def year
    date && date.strftime("%Y")
  end

  def slug
    title && title.downcase.gsub(/\W/i, "-")
  end
end
