require "pygmentize"

class PygmentsRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    Pygmentize.process(code, language)
  end
end
