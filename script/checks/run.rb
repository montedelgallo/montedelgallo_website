# frozen_string_literal: true

# Runs every area check against the built site (_site/). script/check-build.sh builds the
# site first, then calls this; to run it alone after a build:
#
#   bundle exec ruby script/checks/run.rb            # every area, in the order below
#   bundle exec ruby script/checks/run.rb home nav   # only these areas
#
# Prints a "PASS:" line per assertion and stops at the first failure ("FAIL: ..." on
# stderr, exit 1). Exit 0 when every assertion passes.
#
# HOW TO ADD CHECKS
#
#   1. Create script/checks/<area>.rb defining ONE method, check_<area>(ctx). `ctx` is the
#      shared context (lib/site.rb): ctx.site_dir, ctx.site_url, ctx.en_home, ctx.it_home,
#      ctx.css, ctx.year, ctx.fx (the scratch fixture build) and the MIN_* thresholds.
#      Name the helpers of your module with the area as a prefix (<area>_...): every
#      module shares one namespace.
#   2. Add the area name to AREAS below. The order matters only where a module relies on
#      what an earlier one built (the fixture is built on first use, by whoever asks first).
#   3. Use the helpers instead of writing your own:
#        lib/report.rb    pass, fail!, fail_list!(errors, msg), section, assert_file,
#                         assert_contains, require_contains, require_match
#        lib/pages.rb     load_page(url), load_file(path), text_of, meta_description,
#                         skipped_levels, switch_href, footer_of, built_file,
#                         assert_translated_pair, assert_index_pair, assert_link_prefixes,
#                         assert_no_double_prefix, assert_no_shared_assignments
#        lib/images.rb    assert_real_image(public_path, what), Images.inspect_file
#        lib/manifest.rb  manifest_pairs(:projects | :case_studies | :services)
#        lib/fixture.rb   throw-away pages built in a scratch copy of the site (ctx.fx)
#      A check that finds several problems collects them in an array and ends with
#      fail_list!(errors, "what is wrong (see the list above)").
#
# A new area is checked by the first run: add the module, run `bash script/check-build.sh`,
# and make sure it FAILS when the thing it protects is broken (revert the fix, see FAIL).

$stdout.sync = true
Dir.chdir(File.expand_path("../..", __dir__))

require_relative "lib/report"
require_relative "lib/site"
require_relative "lib/images"
require_relative "lib/pages"
require_relative "lib/manifest"
require_relative "lib/fixture"

include Checks::Helpers # rubocop:disable Style/MixinUsage -- the helpers are the checks' vocabulary

# Every area, in the order they run.
AREAS = %w[
  build
  styles
  shell
  nav
  projects
  language_switch
  case_studies
  redirects
  redirects_emit
  services
  i18n
  home
  blog
  company
  contact
].freeze

AREAS.each { |area| require_relative area }

wanted = ARGV.empty? ? AREAS : ARGV
unknown = wanted - AREAS
unless unknown.empty?
  warn "unknown area(s): #{unknown.join(", ")} (known: #{AREAS.join(", ")})"
  exit 2
end

ctx = Checks::Context.new
wanted.each { |area| send("check_#{area}", ctx) }
