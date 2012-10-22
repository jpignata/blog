require "psych"

class IndexFile
  DEFAULT_INDEX_FILE = File.expand_path("articles/index.yaml")

  def initialize(index_file=DEFAULT_INDEX_FILE)
    @index_file = index_file
  end

  def articles
    Psych.load(contents)
  end

  private

  attr_reader :index_file

  def contents
    File.read(index_file)
  end
end
