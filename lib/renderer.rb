require "pygmentize"

class Renderer < Redcarpet::Render::HTML
  include Redcarpet::Render::SmartyPants

  def block_code(code, language)
    Pygmentize.process(code, language)
  end
end
