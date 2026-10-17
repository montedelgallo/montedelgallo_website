# frozen_string_literal: true

require "set"

# The navigation: the labels, where each link leads, the header and footer links, the
# footer columns, the mobile menu and the rule that no page is an orphan.

def check_nav(ctx)
  en_home = ctx.en_home
  it_home = ctx.it_home
  css = ctx.css

  # The navigation labels come from the UI strings of the page's language, in the
  # order given by _data/nav.yml.
  assert_contains en_home, ">Services<", "the nav label must be localized (EN)"
  [["en", en_home], ["it", it_home]].each do |lang, home|
    expected = nav_expected_labels(lang)
    built = nav_built_labels(home)
    (!expected.empty? && built == expected) ||
      fail!("the #{lang} navigation in #{home} reads '#{built}' but _data/nav.yml + _data/i18n/#{lang}.yml say '#{expected}'")
  end
  pass "the navigation shows the localized labels from _data/ in both languages"

  # The check above compares the page with _data/nav.yml, so it stays green when an
  # entry is dropped from nav.yml. The design spec (section 5) fixes the primary
  # navigation as Services, Work, About, Blog, Contact, and each one now leads to its
  # own page: pin the real targets, per language (polyglot puts /it/ in front of the
  # Italian ones). The Book-a-call button stays the Soshiki link.
  fail_list!(nav_target_errors("en", en_home), "the English navigation does not lead to the real pages (see the list above)")
  fail_list!(nav_target_errors("it", it_home), "the Italian navigation does not lead to the real pages (see the list above)")
  pass "the navigation leads to Services, Work, About, Blog and Contact pages in both languages (no home anchor left)"

  # Every link of the header and the footer, on both homes: resolves to a page built in the SAME
  # language (the Italian ones under /it/), and none is a home anchor (/#...) or the bare home
  # (the brand link is the one way to the home). The language switch is the link that crosses over.
  fail_list!(nav_chrome_link_errors("en", en_home, ctx.site_dir), "the English header/footer has a link that is wrong (see the list above)")
  fail_list!(nav_chrome_link_errors("it", it_home, ctx.site_dir), "the Italian header/footer has a link that is wrong (see the list above)")
  pass "every header and footer link of both homes leads to a built page of its own language, none to a home anchor or the bare home"

  # The footer columns: the Company column links the company pages in order, the Services column
  # the real service pages.
  fail_list!(nav_footer_column_errors("en", en_home), "the English footer columns are wrong (see the list above)")
  fail_list!(nav_footer_column_errors("it", it_home), "the Italian footer columns are wrong (see the list above)")
  pass "the footer lists the eight company pages and the real service pages, in both languages"

  nav_mobile_menu(ctx, css)

  # No orphan page: every built page (the 404 excepted) is linked from the header, the footer or an
  # index page of its own language.
  fail_list!(nav_orphan_errors(ctx.site_dir), "there are orphan pages (see the list above)")
  pass "no orphan page: every built page of both languages is reached from the header, the footer or an index page"
end

def nav_expected_labels(lang)
  strings = YAML.load_file("_data/i18n/#{lang}.yml")
  YAML.load_file("_data/nav.yml")["main"].map { |item| strings["nav"][item["key"]] }.join("|")
end

# The text of each link of <nav class="nav__links">, joined with "|".
def nav_built_labels(file)
  flat = Checks::Site.read(file).tr("\n", " ")
  nav = flat[/<nav class="nav__links"[^>]*>.*/].to_s.sub(%r{</nav>.*\z}, "")
  nav.scan(%r{>([^<>]+)</a>}).flatten.map { |label| label.gsub("&amp;", "&") }.join("|")
end

def nav_target_errors(lang, file)
  page = load_file(file)
  strings = YAML.load_file("_data/i18n/#{lang}.yml")
  want = {
    "en" => [["nav.services", "/services/"], ["nav.work", "/projects/"], ["nav.about", "/about/"], ["nav.blog", "/blog/"], ["nav.contact", "/contact/"]],
    "it" => [["nav.services", "/it/servizi/"], ["nav.work", "/it/progetti/"], ["nav.about", "/it/chi-siamo/"], ["nav.blog", "/it/articoli/"], ["nav.contact", "/it/contatti/"]]
  }.fetch(lang).map { |key, href| [strings.dig(*key.split(".")).to_s, href] }
  got = page.css("nav.nav__links a").map { |a| [a.text.strip, a["href"]] }
  errors = []
  errors << "the main navigation must be #{want.inspect} (design spec section 5: Services, Work, About, Blog, Contact, each on its own page), it is #{got.inspect}" unless got == want
  cta = page.at_css("header.nav a.btn--solid")
  errors << "the header's Book-a-call button must stay the Soshiki link, it is #{cta && cta["href"].inspect}" unless cta && cta["href"] == YAML.load_file("_data/site_meta.yml")["booking_url"]
  errors
end

def nav_chrome_link_errors(lang, file, site_dir)
  page = load_file(file)
  home = lang == "it" ? "/it/" : "/"
  errors = []
  links = page.css("header.nav a[href], footer.foot a[href]").reject { |a| a["class"].to_s.split.include?("langsw__link") }
  errors << "found only #{links.size} header/footer links" if links.size < 20
  links.each do |a|
    href = a["href"].to_s
    label = a.text.strip.gsub(/\s+/, " ")
    next if href.start_with?("mailto:", "tel:") || href =~ %r{\Ahttps?://}
    next if a["class"].to_s.split.include?("brand") && href == home

    where = "<a href=#{href.inspect}> #{label.inspect}"
    errors << "#{where} points at a home anchor or the home itself" if href == "/" || href == "/it/" || href.include?("#")
    prefixed = lang == "it" ? href.start_with?("/it/") : !href.start_with?("/it/") && href.start_with?("/")
    errors << "#{where} is not in the #{lang} site" unless prefixed
    path = href.sub(/[?#].*\z/, "")
    path += "index.html" if path.end_with?("/")
    errors << "#{where} leads to no built page" unless File.file?(File.join(site_dir, path))
  end
  errors.uniq
end

def nav_footer_column_errors(lang, file)
  page = load_file(file)
  pre = lang == "it" ? "/it" : ""
  slug = if lang == "it"
           { "company" => %w[servizi casi-di-studio chi-siamo articoli studio-startup laboratorio-prodotto lavora-con-noi motioforge], "services" => %w[software-su-misura ai-e-automazione sistemi-di-dati siti-web app-mobile], "root" => "servizi" }
         else
           { "company" => %w[services case-studies about blog startup-studio product-lab careers motioforge], "services" => %w[custom-software ai-automation data-systems websites mobile-apps], "root" => "services" }
         end
  want_company = slug["company"].map { |s| "#{pre}/#{s}/" }
  want_services = slug["services"].map { |s| "#{pre}/#{slug["root"]}/#{s}/" }
  cols = page.css("footer.foot > .wrap > div").to_h { |d| [d.at_css(".foot__title")&.text.to_s, d.css("ul a").map { |a| a["href"] }] }
  strings = YAML.load_file("_data/i18n/#{lang}.yml")["footer"]
  errors = []
  errors << "the Company column must link #{want_company.inspect}, it links #{cols[strings["company"]].inspect}" unless cols[strings["company"]] == want_company
  errors << "the Services column must link #{want_services.inspect}, it links #{cols[strings["services"]].inspect}" unless cols[strings["services"]] == want_services
  errors
end

# The mobile menu (below 860px the links used to be hidden, so a phone had no navigation): a
# button that controls the menu, collapsed by default, with a label in the page's language; the
# script is deferred; the CSS has the narrow-screen rules, the reduced-motion guard and the
# no-JS fallback (the menu is open unless the page says <html class="js">).
def nav_mobile_menu(ctx, css_file)
  site_dir = ctx.site_dir
  fail_list!(nav_mobile_menu_errors("en", ctx.en_home), "the English mobile menu markup is wrong (see the list above)")
  fail_list!(nav_mobile_menu_errors("it", ctx.it_home), "the Italian mobile menu markup is wrong (see the list above)")
  fail_list!(nav_mobile_menu_errors("en", "#{site_dir}/contact/index.html"), "the mobile menu is missing on an inner page (see the list above)")
  nav_js = "#{site_dir}/assets/js/nav.js"
  assert_file nav_js, "the menu script"
  css = Checks::Site.read(css_file)
  css.match?(/@media ?\(max-width: ?860px\)\{[^@]*\.nav__toggle/) || fail!("#{css_file} has no (max-width:860px) rule for .nav__toggle")
  css.match?(/@media ?\(prefers-reduced-motion: ?reduce\)\{[^@]*\.nav__menu/) || fail!("#{css_file} has no prefers-reduced-motion guard for .nav__menu")
  css.match?(/\.js \.nav__menu:not\(\.is-open\)\{display:none/) || fail!("#{css_file} must collapse the menu only under .js (.js .nav__menu:not(.is-open){display:none}): without JavaScript the links must stay reachable")
  css.match?(/\.nav__toggle(,[^{]*)?\{[^}]*display:none/) || fail!("#{css_file}: the toggle must be hidden by default (no JavaScript, desktop)")
  # The menu is only collapsed INSIDE the narrow-screen media query: the desktop bar is untouched.
  nav_collapse_rule_error(css) and
    fail!("#{css_file} collapses the menu outside the (max-width:860px) media query: the desktop header would lose its links")
  Checks::Site.read(ctx.en_home).include?("document.documentElement.className") || fail!("#{ctx.en_home} has no head script that flips no-js to js")
  # nav.js reverts to the no-JS layout when anything throws (a menu that cannot open must not stay collapsed).
  js = Checks::Site.read(nav_js)
  (js.include?("catch") && js.match?(/classList\.remove\( *['"]js['"] *\)/) && js.match?(/classList\.add\( *['"]no-js['"] *\)/)) ||
    fail!("#{nav_js} must wrap its setup in try/catch and swap <html>'s js class for no-js (classList.remove('js'), classList.add('no-js')) on any error")
  if js.match?(/className *=[^=]/)
    fail!("#{nav_js} overwrites <html>'s className: use a classList swap so the other classes survive")
  end
  # The phone Book button: hidden on a desktop, shown in the bar below 860px; the menu's own copy goes then.
  css.match?(/\.nav__book(,[^{]*)?\{[^}]*display:none/) || fail!("#{css_file}: .nav__book must be hidden by default (the desktop bar has the button in .nav__cta)")
  css.match?(/@media ?\(max-width: ?860px\)\{[^@]*\.nav__book\{[^}]*display:inline-flex/) || fail!("#{css_file}: .nav__book must be shown (display:inline-flex) in the (max-width:860px) media query")
  css.match?(/\.no-js \.nav\{position:static/) || fail!("#{css_file}: the no-JS open menu must not stay stuck (.no-js .nav{position:static})")
  pass "mobile menu: button (constant Menu label) with aria-expanded=false + aria-controls (EN, IT, inner page), Book in the phone bar, deferred nav.js with onerror + try/catch classList swap back to no-js, <=860px CSS, reduced-motion guard, no-JS fallback"
end

# nil when the collapse rule is inside the (max-width:860px) media query, else the reason.
def nav_collapse_rule_error(css)
  at = css.index(".js .nav__menu:not(.is-open)") or return "no collapse rule"
  before = css[0...at]
  depth = before.count("{") - before.count("}")
  query = before.rindex("@media")
  "the collapse rule is at depth #{depth}" unless depth == 1 && query && before[query, 40] =~ /max-width: ?860px/
end

def nav_mobile_menu_errors(lang, file)
  page = load_file(file)
  nav = YAML.load_file("_data/i18n/#{lang}.yml")["nav"]
  errors = []
  buttons = page.css("header.nav button.nav__toggle")
  errors << "header.nav must hold exactly one button.nav__toggle, it holds #{buttons.size}" unless buttons.size == 1
  if (b = buttons.first)
    errors << "the toggle must be type=\"button\"" unless b["type"] == "button"
    errors << "the toggle must start with aria-expanded=\"false\", it has #{b["aria-expanded"].inspect}" unless b["aria-expanded"] == "false"
    menu = page.at_css("[id=\"#{b["aria-controls"]}\"]") if b["aria-controls"].to_s != ""
    errors << "aria-controls=#{b["aria-controls"].inspect} must name the element that holds the navigation" unless menu && menu.at_css("nav.nav__links")
    errors << "the menu must also hold the language switch" unless menu && menu.at_css("nav.langsw")
    # One constant accessible name: the state is carried by aria-expanded alone.
    errors << "the toggle's accessible name must be the constant #{nav["menu"].inspect}, it is #{b["aria-label"].inspect}" unless b["aria-label"] == nav["menu"]
    errors << "the toggle must not carry state labels (data-label-open/data-label-close): the name is constant" if b["data-label-open"] || b["data-label-close"]
    # The primary call to action stays one tap away on a phone: a Book button in the bar itself
    # (a direct child of the header's wrap, outside the menu), with the short visible label and the
    # full label as its accessible name, plus the desktop one inside the menu.
    cta = YAML.load_file("_data/i18n/#{lang}.yml")["cta"]
    book = page.at_css("header.nav > .wrap > a.nav__book")
    errors << "the bar needs a direct child a.nav__book (the Book-a-call button of the phone header)" unless book
    if book
      errors << "a.nav__book must show the short label #{cta["book_call_short"].inspect}, it shows #{book.text.strip.inspect}" unless book.text.strip == cta["book_call_short"]
      errors << "a.nav__book needs aria-label=#{cta["book_call"].inspect} (the visible text is shortened), it has #{book["aria-label"].inspect}" unless book["aria-label"] == cta["book_call"]
      errors << "a.nav__book must lead to the booking page" unless book["href"] == YAML.load_file("_data/site_meta.yml")["booking_url"]
      errors << "a.nav__book must come before the toggle in the DOM (tab order = visual order)" unless book.next_element && book.next_element == b
    end
    errors << "the desktop Book button (.nav__cta a.btn--solid) is missing from the menu wrapper" unless menu && menu.at_css(".nav__cta a.btn--solid")
  end
  js = page.css("script[src]").find { |s| s["src"].to_s.end_with?("/assets/js/nav.js") }
  errors << "nav.js must be loaded with a <script src=\"/assets/js/nav.js\" defer>" unless js && js.has_attribute?("defer")
  # A failed load must give the open (no-JS) layout back: the script tag reverts js -> no-js.
  # It swaps the class (classList: remove js, add no-js) and never overwrites className, which would drop any other class of <html>.
  onerror = js && js["onerror"].to_s
  errors << "the nav.js <script> needs an onerror handler that swaps <html>'s js class for no-js with classList.remove('js') and classList.add('no-js'), it has #{onerror.inspect}" unless onerror && onerror.match?(/classList\.remove\(\s*["']js["']\s*\)/) && onerror.match?(/classList\.add\(\s*["']no-js["']\s*\)/)
  errors << "the onerror handler must not overwrite className (it would drop the other classes of <html>): #{onerror.inspect}" if onerror&.match?(/className\s*=(?!=)/)
  errors << "<html> must start as class=\"no-js\" (the fallback until the head script flips it)" unless page.at_css("html")["class"].to_s.split.include?("no-js")
  errors
end

# The index pages are the ones the headers and footers lead to (and the home); the walk goes
# one level in: header/footer links of the home, plus the links on those pages that lead to a
# built page.
def nav_orphan_errors(site_dir)
  # Every built HTML page: dir/index.html is served at /dir/, any other foo.html at /foo.html.
  url_of = lambda do |f|
    rel = "/" + f.sub(%r{\A#{Regexp.escape(site_dir)}/}, "")
    rel.end_with?("/index.html") ? rel.sub(/index\.html\z/, "") : rel
  end
  file_of = ->(url) { File.join(site_dir, url.end_with?("/") ? "#{url}index.html" : url) }
  pages = Dir.glob(File.join(site_dir, "**/*.html")).reject { |f| f.start_with?(File.join(site_dir, "assets") + "/") }.map(&url_of)
  pages -= ["/404/", "/404.html", "/it/404/", "/it/404.html"]
  errors = []
  %w[en it].each do |lang|
    prefix = lang == "it" ? "/it/" : "/"
    mine = pages.select { |p| lang == "it" ? p.start_with?("/it/") : !p.start_with?("/it/") }
    links_of = lambda do |url|
      file = file_of.(url)
      return [] unless File.file?(file)

      load_file(file).css("a[href]").map { |a| a["href"].sub(/[?#].*\z/, "") }.select { |h| h.start_with?("/") }
    end
    chrome = lambda do |url|
      load_file(file_of.(url)).css("header.nav a[href], footer.foot a[href]").map { |a| a["href"].sub(/[?#].*\z/, "") }.select { |h| h.start_with?("/") }
    end
    reached = Set.new
    indexes = Set.new([prefix])
    chrome.(prefix).each { |h| reached << h; indexes << h if mine.include?(h) }
    # An index page links its children (the projects, the case studies, the articles, the services).
    indexes.dup.each { |i| links_of.(i).each { |h| reached << h if mine.include?(h) } }
    mine.each { |p| errors << "#{lang}: #{p} is linked from no header, footer or index page" unless reached.include?(p) || p == prefix }
  end
  errors
end
