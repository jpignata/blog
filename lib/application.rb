require "sinatra"
require "haml"

require_relative "article"
require_relative "article_index"
require_relative "index_file"
require_relative "content_file"
require_relative "atom_feed"

class Application < Sinatra::Base
  configure do
    set :root, File.expand_path(File.dirname(__FILE__) + "..")
    set :public_folder, "public"
    set :views, "views"
  end

  before do
    @article_index = ArticleIndex.instance
  end

  get "/" do
    articles = @article_index.all
    article  = @article_index.latest

    haml :article, locals: { articles: articles, article: article }
  end

  get "/index.atom" do
    content_type "application/atom+xml"
    AtomFeed.new(@article_index.all).to_xml
  end

  get "/*" do
    permalink = params[:splat].join("/").prepend("/")
    articles  = @article_index.all

    if article = @article_index.find_by_permalink(permalink)
      haml :article, locals: { articles: articles, article: article }
    else
      status 404
      haml :not_found
    end
  end
end
