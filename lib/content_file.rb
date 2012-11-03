require "redcarpet"

require_relative "renderer"

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
    markdown_renderer.render(file_contents)
  end

  def markdown_renderer
    Redcarpet::Markdown.new(Renderer,
      autolink:            true,
      space_after_headers: true,
      fenced_code_blocks:  true
    )
  end

  def file_contents
    File.read(file_path)
  end
end
