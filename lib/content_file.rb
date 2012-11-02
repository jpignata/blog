require "redcarpet"

require_relative "pygments_renderer"

class ContentFile
  def initialize(file_path)
    @file_path = file_path
  end

  def content
    read_and_parse_file
  end

  private

  attr_reader :file_path

  def read_and_parse_file
    html = markdown_renderer.render(file_contents)
    smartypants_renderer.render(html)
  end

  def markdown_renderer
    Redcarpet::Markdown.new(PygmentsRenderer,
      autolink:            true,
      space_after_headers: true,
      fenced_code_blocks:  true
    )
  end

  def smartypants_renderer
    Redcarpet::Render::SmartyPants
  end

  def file_contents
    File.read(file_path)
  end
end
