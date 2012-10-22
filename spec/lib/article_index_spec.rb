require "spec_helper"
require "article_index"
require "article"

describe ArticleIndex do
  let(:first) {
    Article.new(
      "title"     => "first",
      "date"      => Date.parse("02/01/1989"),
      "permalink" => "/first.html"
    )
  }

  let(:second) {
    Article.new(
      "title"     => "second",
      "date"      => Date.parse("05/01/1995"),
      "permalink" => "/second.html"
    )
  }

  let(:third) {
    Article.new(
      "title"     => "third",
      "date"      => Date.parse("09/01/2001"),
      "permalink" => "/third.html"
    )
  }

  let(:articles) { [second, first, third] }

  subject(:article_index) { ArticleIndex.new(articles) }

  describe "#all" do
    it "returns all articles sorted in descending order by date" do
      article_index.all.should eq([third, second, first])
    end
  end

  describe "#latest" do
    it "returns the latest article" do
      article_index.latest.should eq(third)
    end
  end

  describe "#find_by_permalink" do
    it "returns the matching article" do
      article_index.find_by_permalink("/first.html").should eq(first)
    end

    it "returns nil if no article can be found" do
      article_index.find_by_permalink("/pretend.html").should be_nil
    end
  end
end
