# frozen_string_literal: true

require "find"
require "nokogiri"
require "yaml"

# The built site: where it lives, how to read a page of it, and the shared
# context handed to every check module.

module Checks
  SITE_DIR = "_site"

  module Site
    # Files that grep -I would skip as binary: never read as text.
    BINARY_EXT = %w[.webp .jpg .jpeg .png .gif .ico .woff .woff2 .ttf .otf .pdf .zip].freeze

    @texts = {}
    @pages = {}
    @text_files = {}

    class << self
      # The public origin, read from _config.yml so the checks follow a change of domain.
      def url
        @url ||= begin
          value = YAML.load_file("_config.yml", aliases: true)["url"].to_s.strip
          fail!("could not read 'url' from _config.yml") if value.empty?
          value
        end
      end

      # The text of a file (cached: a page is read once per run).
      def read(path)
        @texts[path] ||= File.read(path, encoding: "utf-8")
      end

      # A built page as a Nokogiri HTML5 document (cached).
      def page(path)
        @pages[path] ||= Nokogiri::HTML5(read(path))
      end

      # Every text file under `root` (what `grep -rI` would search).
      def text_files(root)
        @text_files[root] ||= Find.find(root).select do |path|
          File.file?(path) && !BINARY_EXT.include?(File.extname(path).downcase) &&
            !File.binread(path, 8000).to_s.include?("\0")
        end.sort
      end

      # Files under `root` that contain the literal text (`grep -rIlF`).
      def grep_tree(needle, root, except_ext: [])
        text_files(root).reject { |path| except_ext.include?(File.extname(path)) }
                        .select { |path| read(path).include?(needle) }
      end
    end
  end

  # The shared context every check module receives: the paths and constants of
  # the run, and the things that are expensive to build and shared (the scratch
  # fixture build). Add a reader here when two modules need the same value.
  class Context
    # What the live site had and the client expects to find (see each module).
    MIN_PROJECTS = 12
    FEATURED_PROJECTS = 3
    MIN_BODY_CHARS = 500
    MIN_CASE_STUDIES = 3
    MIN_CASE_BODY_CHARS = 400
    MIN_SERVICES = 8
    MIN_SERVICE_BODY_CHARS = 400
    MIN_POSTS = 9
    MIN_POST_BODY_CHARS = 600

    # ctx.min_projects, ctx.featured_projects, ctx.min_body_chars ...
    constants.each { |name| define_method(name.to_s.downcase) { self.class.const_get(name) } }

    def site_dir = SITE_DIR
    def site_url = Site.url
    def en_home = "#{SITE_DIR}/index.html"
    def it_home = "#{SITE_DIR}/it/index.html"
    def css = "#{SITE_DIR}/assets/css/main.css"
    def year = Time.now.strftime("%Y")

    # The built scratch site (see lib/fixture.rb), built on first use.
    def fx
      @fx ||= Fixture.build
    end
  end
end
