require "spec_helper"
require "index_file"

describe IndexFile do
  subject(:index_file) {
    index_file = IndexFile.new("spec/fixtures/index.yaml")
  }

  it "returns the an array of the articles in the given YAML file" do
    index_file.should have(2).articles
  end

  it "returns each article's attributes" do
    index_file.articles[0].should eq(
      "date"      => Date.parse("2012-10-22"),
      "title"     => "First blog post",
      "summary"   => "Some kind of introductory blog post",
      "file_name" => "first_post.md"
    )

    index_file.articles[1].should eq(
      "date"      => Date.parse("2012-10-25"),
      "title"     => "Second blog post",
      "summary"   => "Some kind of sophmore blog post",
      "file_name" => "second_post.md"
    )
  end
end
