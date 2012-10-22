require "spec_helper"
require "article"

describe Article do
  let(:file_parser) { stub }

  describe ".inflate" do
    it "returns an Article for each attributes hash passed" do
      articles_attributes = [
        {
          "date"      => Date.parse("01/01/2010"),
          "title"     => "title 1",
          "summary"   => "summary 1",
          "file_name" => "one.md"
        },

        {
          "date"      => Date.parse("05/01/2010"),
          "title"     => "title 2",
          "summary"   => "summary 2",
          "file_name" => "two.md"
        }
      ]

      Article.inflate(articles_attributes, file_parser: file_parser).
        should have(2).articles
    end
  end

  describe ".new" do
    it "seta the permalink" do
      attributes = { "permalink" => "/permalink.html" }
      article = Article.new(attributes, file_parser: file_parser)
      article.permalink.should eq("/permalink.html")
    end

    it "defaults the permalink to /year/month/slug.html if not provided" do
      attributes = {
        "date"  => Date.parse("05/05/2006"),
        "title" => "something about something"
      }
      article = Article.new(attributes, file_parser: file_parser)
      article.permalink.should eq("/2006/05/something-about-something.html")
    end
  end

  describe "<=>" do
    it "sorts descendingly by date" do
      article_1 = Article.new(
        { "date" => Date.parse("01/01/2001") },
        file_parser: file_parser
      )

      article_2 = Article.new(
        { "date" => Date.parse("02/01/2001") },
        file_parser: file_parser
      )

      [article_1, article_2].sort.should eq([article_2, article_1])
    end
  end

  describe "#content" do
    it "returns article file content using the content file parser" do
      file_parser_instance = stub
      file_parser_instance.should_receive(:content).and_return("content")

      file_parser.
        should_receive(:new).
        with("articles/article.md").
        and_return(file_parser_instance)

      article = Article.new(
        { "file_name" => "article.md" },
        file_parser: file_parser
      )

      article.content.should eq("content")
    end
  end
end
