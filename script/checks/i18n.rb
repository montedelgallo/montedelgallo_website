# frozen_string_literal: true

# The UI strings (_data/i18n/en.yml, it.yml): both languages define the same keys, and
# every navigation entry (_data/nav.yml) is complete.

# Every value of a file, with its path ("home.services.items.0.title"). A list is
# read item by item, so the two languages are compared item by item too.
def i18n_leaves(node, path = [])
  case node
  when Hash, Array
    return [[path.join("."), node]] if node.empty? # no text at all: reported below

    pairs = node.is_a?(Hash) ? node.map { |key, value| [key.to_s, value] } : node.each_with_index.map { |value, index| [index.to_s, value] }
    pairs.flat_map { |key, value| i18n_leaves(value, path + [key]) }
  else
    [[path.join("."), node]]
  end
end

def check_i18n(_ctx)
  section "Asserting the UI strings (EN and IT define the same keys, every nav entry is complete)"
  fail_list!(i18n_errors, "the UI strings in _data/ are inconsistent (see the list above)")
  pass "en.yml and it.yml have the same keys (lists item by item), all non-empty, no icon differing by language, no long sentence left in English; every nav entry has an href and a label in both languages"
end

def i18n_errors
  langs = %w[en it]
  strings = langs.to_h { |lang| [lang, i18n_leaves(YAML.load_file("_data/i18n/#{lang}.yml")).to_h] }
  errors = []

  (strings["en"].keys - strings["it"].keys).each { |k| errors << "i18n key #{k} is in en.yml but not in it.yml" }
  (strings["it"].keys - strings["en"].keys).each { |k| errors << "i18n key #{k} is in it.yml but not in en.yml" }
  strings.each do |lang, map|
    map.each do |key, value|
      ok = value.is_a?(String) && !value.strip.empty?
      errors << "#{lang}.yml: #{key} is #{value.inspect}, but every value must be a non-empty string" unless ok
    end
  end

  shared = strings["en"].keys & strings["it"].keys
  # An icon is the name of a symbol of the sprite, not a word: it must not change
  # with the language.
  shared.select { |key| key.split(".").last == "icon" }.each do |key|
    errors << "#{key} is #{strings["en"][key].inspect} in en.yml but #{strings["it"][key].inspect} in it.yml: an icon does not change with the language" unless strings["en"][key] == strings["it"][key]
  end
  # A sentence that is word for word the same in both files was pasted, not
  # translated. (A short label can be the same in both: a brand name, "E-commerce".)
  shared.each do |key|
    english = strings["en"][key]
    next unless english.is_a?(String) && english.split.size >= 4

    errors << "it.yml: #{key} is the English text #{english.inspect}, not a translation" if english == strings["it"][key]
  end

  # Where each navigation list finds its labels.
  label_scope = { "main" => "nav", "footer_company" => "footer.links", "footer_services" => "footer.service_links" }
  YAML.load_file("_data/nav.yml").each do |list, items|
    scope = label_scope[list]
    (errors << "nav.yml: list #{list} has no label scope in this check"; next) unless scope

    items.each do |item|
      langs.each do |lang|
        errors << "nav.yml #{list}/#{item["key"]}: no #{lang} href" if item[lang].to_s.strip.empty?
        errors << "#{lang}.yml: no label #{scope}.#{item["key"]} (used by nav.yml #{list})" unless strings[lang].key?("#{scope}.#{item["key"]}")
      end
    end
  end
  errors
end
