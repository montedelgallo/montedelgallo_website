# frozen_string_literal: true

require "date"
require "json"
require "yaml"

# The manifests: the Markdown documents of a collection (_projects, _case_studies,
# _services), read, validated, and handed to the checks as one entry per
# translated pair.
#
# Each collection is a document per language tied together by a shared page_id
# (jekyll-polyglot pairs translations by page_id and ignores a `ref`). Permalinks
# are written WITHOUT the /it/ prefix, because polyglot adds it itself.
#
#   manifest_pairs(:projects)      # => [{ "page_id" =>, "en" => doc, "it" => doc }, ...]
#
# A pair's "it" is nil for an English-only case study (lang-exclusive: [en]).
# The first call validates the collection and fails with the list of problems;
# the pairs are cached for the rest of the run.
#
# To add a collection: write `Manifest.<name>_errors` rules (what each document
# must hold), a row in COLLECTIONS, and use `manifest_pairs(:<name>)`.

module Checks
  module Manifest
    FRONT_MATTER = /\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\z)/m
    LOOSE_FRONT_MATTER = /\A---[ \t]*\n(.*?)\n---/m

    COLLECTIONS = {
      projects: { glob: "_projects/**/*.md", folder: "_projects/", noun: "project", plural: "projects",
                  section: { "en" => "projects", "it" => "progetti" } },
      case_studies: { glob: "_case_studies/**/*.md", folder: "_case_studies/", noun: "case study", plural: "case studies",
                      section: { "en" => "case-studies", "it" => "casi-di-studio" } },
      services: { glob: "_services/**/*.md", folder: "_services/", noun: "service", plural: "services",
                  section: { "en" => "services", "it" => "servizi" } }
    }.freeze

    @pairs = {}

    module_function

    def text?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    # The front matter of every document matching the glob, with its "path".
    def load_docs(glob, folder, noun, errors)
      docs = Dir.glob(glob).sort.filter_map do |path|
        match = File.read(path, encoding: "utf-8").match(FRONT_MATTER)
        (errors << "#{path}: no YAML front matter"; next) unless match
        begin
          front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
        rescue Psych::Exception => e
          errors << "#{path}: the front matter is not valid YAML (#{e.message})"
          next
        end
        (errors << "#{path}: the front matter must be a list of key: value lines"; next) unless front.is_a?(Hash)

        front.merge("path" => path)
      end
      errors << "#{folder} holds no #{noun} document" if docs.empty?
      docs
    end

    # The front matter of a document without judging it (nil when it has none).
    def front_matter(path)
      front = File.read(path, encoding: "utf-8")[LOOSE_FRONT_MATTER, 1]
      YAML.safe_load(front, permitted_classes: [Date, Time]) if front
    end

    # Every project document as a plain hash, for the collections that refer to them.
    def project_docs
      Dir.glob("_projects/**/*.md").filter_map { |path| front_matter(path) }
    end

    # The permalink is bare (no /it/ prefix) and /<section>/<slug>/.
    def permalink_errors(doc, section, errors)
      link = doc["permalink"].to_s
      if link.start_with?("/it/")
        errors << "#{doc["path"]}: permalink #{link} starts with /it/, but jekyll-polyglot adds that prefix itself (the page would be built at /it#{link})"
      elsif section.key?(doc["lang"]) && link !~ %r{\A/#{section[doc["lang"]]}/[a-z0-9]+(?:-[a-z0-9]+)*/\z}
        errors << "#{doc["path"]}: permalink #{link.inspect} must look like /#{section[doc["lang"]]}/<slug>/"
      end
    end

    # A cover or picture path under `folder` that is a file of the repository.
    def repository_image?(path, folder)
      text?(path) && path.start_with?(folder)
    end

    def duplicate_permalink_errors(docs, plural, errors)
      docs.group_by { |doc| [doc["lang"], doc["permalink"]] }.each do |(lang, link), group|
        errors << "two #{lang} #{plural} share the permalink #{link}" if group.size > 1
      end
    end

    def by_id_pairs(by_id)
      by_id.map { |id, group| { "page_id" => id, "en" => group.find { |doc| doc["lang"] == "en" }, "it" => group.find { |doc| doc["lang"] == "it" } } }
    end

    # ---- the cached entry point ----------------------------------------------

    def pairs(collection, **options)
      @pairs[collection] ||= begin
        spec = COLLECTIONS.fetch(collection)
        errors = []
        docs = load_docs(spec[:glob], spec[:folder], spec[:noun], errors)
        result = send("#{collection}_pairs", docs, spec, errors, **options)
        fail_list!(errors, "the #{spec[:noun]} documents in #{spec[:folder]} are invalid (see the list above)")
        # Through JSON, as the checks used to read it (dates and the like become strings).
        JSON.parse(JSON.generate(result))
      end
    end

    # ---- projects ---------------------------------------------------------------

    def projects_pairs(docs, spec, errors)
      section = spec[:section]
      fact_keys = %w[client duration services platforms] # the order the aside shows them in

      docs.each do |doc|
        at = doc["path"]
        %w[title sector summary cover_alt page_id].each do |key|
          errors << "#{at}: #{key} must be a non-empty string" unless text?(doc[key])
        end
        errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
        errors << "#{at}: year must be a number" unless doc["year"].is_a?(Integer)
        errors << "#{at}: stack must be a non-empty list of names" unless doc["stack"].is_a?(Array) && !doc["stack"].empty? && doc["stack"].all? { |s| text?(s) }
        errors << "#{at}: metric needs a value and a label" unless doc["metric"].is_a?(Hash) && text?(doc["metric"]["value"]) && text?(doc["metric"]["label"])
        errors << "#{at}: featured must be true or false" unless [true, false].include?(doc["featured"])

        # Optional: the project's other figures (`metrics`, tiles under the cover; the headline
        # `metric` is the one on the card and stays out of this list) and its facts (`facts`,
        # in the aside: only the keys the live page has).
        if doc.key?("metrics")
          metrics = doc["metrics"]
          unless metrics.is_a?(Array) && !metrics.empty? && metrics.all? { |entry| entry.is_a?(Hash) && entry.keys.sort == %w[label value] && text?(entry["value"]) && text?(entry["label"]) }
            errors << "#{at}: metrics must be a non-empty list of {value, label} maps with non-empty strings"
          end
        end
        if doc.key?("facts")
          facts = doc["facts"]
          unless facts.is_a?(Hash) && !facts.empty? && (facts.keys - fact_keys).empty? && facts.values.all? { |v| text?(v) }
            errors << "#{at}: facts must be a non-empty map of #{fact_keys.join(", ")} (only the ones the project has), each a non-empty string"
          end
        end
        if repository_image?(doc["cover"], "/assets/img/projects/")
          errors << "#{at}: the cover #{doc["cover"]} is not a file in the repository" unless File.file?(doc["cover"].delete_prefix("/"))
        else
          errors << "#{at}: cover must be a path under /assets/img/projects/"
        end

        # Optional: links out of the page (the project's own website, its repository, a
        # demo video), shown as buttons next to the facts.
        if doc.key?("links")
          links = doc["links"]
          unless links.is_a?(Array) && !links.empty? && links.all? { |entry| entry.is_a?(Hash) && text?(entry["label"]) && text?(entry["url"]) && entry["url"].start_with?("https://") }
            errors << "#{at}: links must be a non-empty list of {label, url} maps, each url starting with https://"
          end
        end

        # Optional: a gallery of pictures under the text. Each one carries its size (it
        # reserves the space before the picture arrives) and an alt text; the caption is optional.
        if doc.key?("gallery")
          gallery = doc["gallery"]
          if gallery.is_a?(Array) && !gallery.empty?
            gallery.each_with_index do |shot, index|
              shot_at = "#{at}: gallery item #{index + 1}"
              (errors << "#{shot_at} must be a map with src, alt, width and height"; next) unless shot.is_a?(Hash)
              errors << "#{shot_at}: alt must be a non-empty string" unless text?(shot["alt"])
              errors << "#{shot_at}: caption must be a non-empty string when there is one" if shot.key?("caption") && !text?(shot["caption"])
              errors << "#{shot_at}: width and height must be numbers" unless shot["width"].is_a?(Integer) && shot["height"].is_a?(Integer)
              if repository_image?(shot["src"], "/assets/img/projects/")
                errors << "#{shot_at}: #{shot["src"]} is not a file in the repository" unless File.file?(shot["src"].delete_prefix("/"))
              else
                errors << "#{shot_at}: src must be a path under /assets/img/projects/"
              end
            end
          else
            errors << "#{at}: gallery must be a non-empty list"
          end
        end

        permalink_errors(doc, section, errors)
      end

      by_id = docs.group_by { |doc| doc["page_id"] }
      by_id.each do |id, group|
        langs = group.map { |doc| doc["lang"].to_s }.sort
        errors << "page_id #{id.inspect}: expected one en and one it document (polyglot pairs translations by page_id), found #{langs.inspect}" unless langs == %w[en it]
        errors << "page_id #{id.inspect}: the en and it documents must agree on featured" if group.map { |doc| doc["featured"] }.uniq.size > 1
        # The figures are the same in both languages (only the labels are translated), and so are the facts present.
        en_doc = group.find { |doc| doc["lang"] == "en" }
        it_doc = group.find { |doc| doc["lang"] == "it" }
        next unless en_doc && it_doc

        en_values = (en_doc["metrics"] || []).map { |m| m.is_a?(Hash) ? m["value"] : nil }
        it_values = (it_doc["metrics"] || []).map { |m| m.is_a?(Hash) ? m["value"] : nil }
        errors << "page_id #{id.inspect}: the metrics values of the en document (#{en_values.inspect}) and the it document (#{it_values.inspect}) must match" unless en_values == it_values
        errors << "page_id #{id.inspect}: the en and it documents must declare the same facts (#{(en_doc["facts"] || {}).keys.inspect} vs #{(it_doc["facts"] || {}).keys.inspect})" unless (en_doc["facts"].is_a?(Hash) ? en_doc["facts"].keys : []) == (it_doc["facts"].is_a?(Hash) ? it_doc["facts"].keys : [])
      end
      duplicate_permalink_errors(docs, spec[:plural], errors)
      featured = by_id.values.count { |group| group.all? { |doc| doc["featured"] == true } }
      errors << "the home page shows the featured projects: at least 3 are needed, found #{featured}" if featured < 3

      by_id_pairs(by_id)
    end

    # ---- case studies -----------------------------------------------------------
    #
    # The live site has no pictures for its case studies (the WordPress pages carry no
    # featured image), so `cover` is optional: a case study without one leads with its
    # result figures. A cover that IS declared must be a real image in the repository.

    def case_studies_pairs(docs, spec, errors)
      section = spec[:section]

      docs.each do |doc|
        at = doc["path"]
        %w[title client sector summary challenge solution page_id].each do |key|
          errors << "#{at}: #{key} must be a non-empty string" unless text?(doc[key])
        end
        errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
        errors << "#{at}: stack must be a non-empty list of names" unless doc["stack"].is_a?(Array) && !doc["stack"].empty? && doc["stack"].all? { |s| text?(s) }
        results = doc["results"]
        if results.is_a?(Array) && results.size >= 3
          results.each_with_index do |entry, index|
            errors << "#{at}: results item #{index + 1} needs a value and a label" unless entry.is_a?(Hash) && text?(entry["value"]) && text?(entry["label"])
          end
        else
          errors << "#{at}: results must be a list of at least 3 {value, label} figures"
        end
        if doc.key?("facts")
          facts = doc["facts"]
          errors << "#{at}: facts must be a non-empty map of label: text" unless facts.is_a?(Hash) && !facts.empty? && facts.all? { |k, v| text?(k.to_s) && text?(v) }
        end
        if doc.key?("cover")
          if repository_image?(doc["cover"], "/assets/img/case-studies/")
            errors << "#{at}: the cover #{doc["cover"]} is not a file in the repository" unless File.file?(doc["cover"].delete_prefix("/"))
            errors << "#{at}: a cover needs a cover_alt that describes it" unless text?(doc["cover_alt"])
          else
            errors << "#{at}: cover must be a path under /assets/img/case-studies/"
          end
        end
        permalink_errors(doc, section, errors)
      end

      by_id = docs.group_by { |doc| doc["page_id"] }
      by_id.each do |id, group|
        langs = group.map { |doc| doc["lang"].to_s }.sort
        english_only = langs == %w[en] && group.first["lang-exclusive"] == %w[en]
        errors << "page_id #{id.inspect}: expected one en and one it document, or a single en document with lang-exclusive: [en], found #{langs.inspect}" unless langs == %w[en it] || english_only
      end
      duplicate_permalink_errors(docs, spec[:plural], errors)

      by_id_pairs(by_id)
    end

    # ---- services ---------------------------------------------------------------
    #
    # The set is fixed by the approved home page: the same eight services, in the same
    # order, with the home's titles and icons.

    def services_pairs(docs, spec, errors, wanted: Context::MIN_SERVICES)
      section = spec[:section]
      sprite = File.read("_includes/icons.html", encoding: "utf-8").scan(/id="(i-[a-z-]+)"/).flatten
      projects = project_docs
      home = %w[en it].to_h { |lang| [lang, YAML.load_file("_data/i18n/#{lang}.yml").dig("home", "services", "items")] }

      docs.each do |doc|
        at = doc["path"]
        %w[title summary page_id].each { |key| errors << "#{at}: #{key} must be a non-empty string" unless text?(doc[key]) }
        errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
        errors << "#{at}: icon #{doc["icon"].inspect} is not a symbol of _includes/icons.html (#{sprite.join(", ")})" unless sprite.include?(doc["icon"])
        errors << "#{at}: order must be an integer from 1 to #{wanted}" unless doc["order"].is_a?(Integer) && doc["order"].between?(1, wanted)
        if doc["order"].is_a?(Integer) && home[doc["lang"]] && home[doc["lang"]][doc["order"] - 1]
          item = home[doc["lang"]][doc["order"] - 1]
          errors << "#{at}: service #{doc["order"]} is #{item["title"].inspect} on the home page, its title here is #{doc["title"].inspect}" unless doc["title"] == item["title"]
          errors << "#{at}: service #{doc["order"]} has the icon #{item["icon"]} on the home page, here #{doc["icon"].inspect}" unless doc["icon"] == item["icon"]
        end
        if doc.key?("related_projects")
          related = doc["related_projects"]
          if related.is_a?(Array) && !related.empty? && related.all? { |id| text?(id) }
            related.each do |id|
              langs = projects.select { |project| project["page_id"] == id }.map { |project| project["lang"] }.sort
              errors << "#{at}: related project #{id.inspect} must exist in English and in Italian in _projects/, found #{langs.inspect}" unless langs == %w[en it]
            end
          else
            errors << "#{at}: related_projects must be a non-empty list of project page_ids"
          end
        end
        if doc.key?("faq")
          faq = doc["faq"]
          ok = faq.is_a?(Array) && !faq.empty? && faq.all? { |entry| entry.is_a?(Hash) && text?(entry["q"]) && text?(entry["a"]) }
          errors << "#{at}: faq must be a non-empty list of {q, a} with a question and an answer" unless ok
        end
        permalink_errors(doc, section, errors)
      end

      %w[en it].each do |lang|
        mine = docs.select { |doc| doc["lang"] == lang }
        errors << "#{mine.size} #{lang} service document(s), exactly #{wanted} are expected" unless mine.size == wanted
        errors << "the #{lang} services must have the orders 1 to #{wanted}, each once, found #{mine.map { |doc| doc["order"] }.sort.inspect}" unless mine.map { |doc| doc["order"] }.sort == (1..wanted).to_a
      end
      duplicate_permalink_errors(docs, spec[:plural], errors)
      by_id = docs.group_by { |doc| doc["page_id"] }
      by_id.each do |id, group|
        langs = group.map { |doc| doc["lang"].to_s }.sort
        if langs == %w[en it]
          en = group.find { |doc| doc["lang"] == "en" }
          it = group.find { |doc| doc["lang"] == "it" }
          errors << "page_id #{id.inspect}: the English and Italian documents must have the same order and icon" unless en["order"] == it["order"] && en["icon"] == it["icon"]
          errors << "page_id #{id.inspect}: the English and Italian documents must list the same related_projects" unless en["related_projects"] == it["related_projects"]
          errors << "page_id #{id.inspect}: the English and Italian documents must have the same number of faq entries" unless (en["faq"] || []).size == (it["faq"] || []).size
        else
          errors << "page_id #{id.inspect}: expected one en and one it document, found #{langs.inspect}"
        end
      end

      return [] unless errors.empty?

      by_id_pairs(by_id).sort_by { |pair| pair["en"]["order"] }
    end
  end

  module Helpers
    # The pairs of a collection (:projects, :case_studies, :services), validated and cached.
    def manifest_pairs(collection)
      Manifest.pairs(collection)
    end
  end
end
