# frozen_string_literal: true

# Liquid has no way to write an object, so _includes/jsonld.html could only build its
# structured data by gluing JSON text together, which breaks on the first quote in a title.
# This filter is the missing constructor: it takes a flat list of alternating keys and values
# and returns a Hash, which the template then serializes with `jsonify` (escaping every value).
#
#   {% assign ld_new = "" | split: "," %}
#   {% assign ld_person = ld_new | push: "@type" | push: "Person" | push: "name" | push: page.author | ld_object %}
#
# A pair whose value is nil or an empty string is left out, so an optional property (an image
# a document may not have) is one `push` and not an `if`. Values may be strings, numbers,
# other objects built the same way, or arrays of them.

module Jekyll
  module JsonLdObject
    def ld_object(pairs)
      list = Array(pairs)
      raise Liquid::ArgumentError, "ld_object needs alternating keys and values, got #{list.size} items" if list.size.odd?

      list.each_slice(2).with_object({}) do |(key, value), object|
        next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

        object[key.to_s] = value
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::JsonLdObject)
