require "spec_helper"
require "content_file"

describe ContentFile do
  subject(:content_file) { ContentFile.new("spec/fixtures/content_file.md") }

  it "returns the Markdown-parsed file contents" do
    content_file.content.should eq("<h1>oh hai!</h1>\n\n<p>some content</p>\n")
  end
end
