require "spec_helper"
require "application"
require "rack/test"

describe Application do
  include Rack::Test::Methods

  def app
    Application
  end

  describe "get /splat" do
    before do
      attributes = {
        "title"     => "title",
        "summary"   => "summary",
        "date"      => Date.parse("11/11/2012"),
        "file_name" => "content_file.md"
      }

      article = Article.new(attributes, file_directory: "spec/fixtures")
      index   = ArticleIndex.new([article])

      ArticleIndex.instance = index
    end

    it "returns the page requested" do
      get "/2012/11/title.html"

      last_response.should be_ok
      last_response.body.should match(/November 11, 2012/)
      last_response.body.should match(/oh hai!/)
    end

    it "returns a 404 if article not found" do
      get "/pretend.html"
      last_response.status.should eq(404)
      last_response.body.should match(/lol. i don't know/)
    end
  end
end
