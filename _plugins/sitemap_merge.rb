# frozen_string_literal: true

# Merges the Italian sitemap into the root one, so there is ONE /sitemap.xml.
#
# sitemap.xml (the source page) is built once per language by jekyll-polyglot: the English
# build writes /sitemap.xml with the English pages, the Italian build writes /it/sitemap.xml
# with the Italian ones. Each build only sees the documents of its own language, so neither
# could list the other's pages (an article in Italian only is invisible to the English
# build). Once every language is written, this hook moves the <url> entries of the Italian
# file into the root file (an entry both builds list is kept once, by its <loc>) and deletes
# /it/sitemap.xml. script/checks/sitemap.rb asserts the result.

Jekyll::Hooks.register :polyglot, :post_write do |site|
  root = File.join(site.dest, "sitemap.xml")
  site.languages.each do |lang|
    next if lang == site.default_lang

    other = File.join(site.dest, lang, "sitemap.xml")
    raise "sitemap: #{other} was not written, so the #{lang} pages cannot be added to #{root}" unless File.file?(other)
    raise "sitemap: #{root} was not written" unless File.file?(root)

    entry = %r{<url>.*?</url>}m
    xml = File.read(root, encoding: "utf-8")
    known = xml.scan(/<loc>(.*?)<\/loc>/m).flatten
    added = File.read(other, encoding: "utf-8").scan(entry).reject { |url| known.include?(url[/<loc>(.*?)<\/loc>/m, 1]) }
    xml = xml.sub("</urlset>") { "#{added.join("\n")}\n</urlset>" } unless added.empty?
    File.write(root, xml)
    File.delete(other)
  end
end
