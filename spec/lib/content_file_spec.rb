require "spec_helper"
require "content_file"

describe ContentFile do
  subject(:content_file) { ContentFile.new("spec/fixtures/content_file.md") }

  it "returns the Markdown-parsed file contents" do
    content_file.content.should include("<h1>oh hai!</h1>\n\n<p>some content</p>\n")
  end

  it "turns primes into smart quotes" do
    content_file.content.should include(%q{&ldquo;or something&rdquo;})
  end

  it "renders pygmentized code blocks" do
    content_file.content.should include(%q{<div class="highlight">})
  end
end
