require "redcarpet"

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
    renderer.render(file_contents)
  end

  def renderer
    @renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML,
      autolink: true,
      space_after_headers: true
    )
  end

  def file_contents
    File.read(file_path)
  end
end
