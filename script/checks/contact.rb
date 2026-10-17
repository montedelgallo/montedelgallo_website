# frozen_string_literal: true

# The contact page, the Soshiki form and the legal placeholders.
#
# The contact form is the client's own Soshiki form (_includes/contact-form.html): its
# action, method, field names, ids, types, required flags, rows and honeypot are the ones
# Soshiki gave, character for character; only the visible words (i18n), the classes and
# the autocomplete hints are ours. Booking is a plain link to booking_url (the Soshiki
# embed widget is deferred, see the plan): neither embed.js nor data-sk-booking may ship.
# The direct contacts are selectable text AND links. The Privacy and Cookie pages are
# DRAFTS: bannered, noindex, out of the sitemap, and they state only known facts.

SOSHIKI_ACTION = "https://soshiki.io/f/l3opjfhj10ocxgca"

def check_contact(ctx)
  section "Asserting the contact page, the Soshiki form and the legal placeholders"
  site_dir = ctx.site_dir
  booking_url = YAML.load_file("_data/site_meta.yml")["booking_url"].to_s
  fail!("_data/site_meta.yml has no booking_url") if booking_url.empty?
  assert_file "_includes/contact-form.html", "the Soshiki contact form include"
  require_contains "_includes/contact-form.html", "action=\"#{SOSHIKI_ACTION}\"", "the Soshiki form action must be kept verbatim"
  assert_no_shared_assignments ["_includes/contact-form.html"],
                               "_includes/contact-form.html assigns (or loops with) t, lang or p: give the variable a prefix of its own"

  fail_list!(contact_page_errors("en", "#{site_dir}/contact/index.html", booking_url), "the English contact page is wrong (see the list above)")
  fail_list!(contact_page_errors("it", "#{site_dir}/it/contatti/index.html", booking_url), "the Italian contact page is wrong (see the list above)")
  pass "contact page (EN + IT): Soshiki form verbatim (action, POST, 4 fields with name/id/type/required, rows=5, hidden honeypot, a label for each, no other field), privacy notice linking the privacy page of the language, booking button -> booking_url, WhatsApp/tel/mailto links with the number, email and address as text"

  # No Soshiki embed anywhere: the widget's session cookie and hard-coded Italian labels
  # make it a decision for the next plan.
  embed_hit = Checks::Site.text_files(site_dir).find { |path| Checks::Site.read(path).match?(/embed\.js|data-sk-booking/) }
  embed_hit && fail!("the built site ships the Soshiki embed (embed.js / data-sk-booking) in #{embed_hit}: booking is a link-out only")
  pass "no Soshiki embed.js or data-sk-booking anywhere in the built site"

  contact_legal_pages(ctx)

  # The Italian article that invites the reader to write to us leads to the Italian contact page.
  design_post = "#{site_dir}/it/articoli/design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025/index.html"
  assert_file design_post, "the Italian article that ends with a contact link"
  html = Checks::Site.read(design_post)
  html.include?(">Scrivici oggi stesso!</strong></a>") || fail!("#{design_post} lost its 'Scrivici oggi stesso!' link")
  html.match?(%r{<a href="/it/contatti/">(<strong>)?Scrivici oggi stesso!}) || fail!("the 'Scrivici oggi stesso!' link of #{design_post} must lead to /it/contatti/")
  pass "the Italian article's contact link leads to /it/contatti/"

  # The form's CSS, read from the compiled file: full-width fields, a comfortable tap target,
  # 1rem text (a smaller size makes iOS zoom into the field).
  css_file = ctx.css
  css = Checks::Site.read(css_file)
  css.match?(/\.cform__control\{[^}]*width:100%/) || fail!("the .cform__control rule in #{css_file} must make the fields width:100%")
  css.match?(/\.cform__control\{[^}]*min-height:48px/) || fail!("the .cform__control rule in #{css_file} must give a 48px minimum height (tap target)")
  css.match?(/\.cform__control\{[^}]*font-size:1rem/) || fail!("the .cform__control rule in #{css_file} must be font-size:1rem (no iOS zoom)")
  pass "the form fields are full width, 48px tall at least, 1rem text"

  assert_no_double_prefix
  pass "no /it/it/ anywhere in the built site"
end

def contact_page_errors(lang, file, booking)
  errors = []
  page = load_file(file)
  main = page.at_css("main")
  strings = YAML.load_file("_data/i18n/#{lang}.yml").fetch("contact")
  company = YAML.load_file("_data/site_meta.yml").fetch("company")
  hrefs = main.css("a[href]").map { |a| a["href"] }
  text = main.text.gsub(/\s+/, " ")

  # --- the form, character for character
  forms = main.css("form")
  errors << "#{lang}: main must hold exactly one <form>, it holds #{forms.size}" unless forms.size == 1
  form = forms.first
  if form
    errors << "#{lang}: form action must be #{SOSHIKI_ACTION}, it is #{form["action"].inspect}" unless form["action"] == SOSHIKI_ACTION
    errors << "#{lang}: form method must be POST, it is #{form["method"].inspect}" unless form["method"] == "POST"
    fields = { "nome" => ["input", "text", true, "sk-nome", "name"], "email" => ["input", "email", true, "sk-email", "email"],
               "telefono" => ["input", "tel", false, "sk-telefono", "tel"], "messaggio" => ["textarea", nil, true, "sk-messaggio", nil] }
    fields.each do |name, (tag, type, required, id, autocomplete)|
      node = form.at_css("#{tag}[name='#{name}']")
      (errors << "#{lang}: no <#{tag} name=\"#{name}\"> in the form"; next) unless node

      errors << "#{lang}: #{name} must have id=#{id.inspect}, it has #{node["id"].inspect}" unless node["id"] == id
      errors << "#{lang}: #{name} must have type=#{type.inspect}, it has #{node["type"].inspect}" if type && node["type"] != type
      errors << "#{lang}: #{name} must #{required ? "" : "not "}be required" unless node.has_attribute?("required") == required
      errors << "#{lang}: #{name} should hint autocomplete=#{autocomplete.inspect}, it has #{node["autocomplete"].inspect}" if autocomplete && node["autocomplete"] != autocomplete
      label = form.at_css("label[for='#{id}']")
      errors << "#{lang}: #{name} has no <label for=\"#{id}\">" unless label
      errors << "#{lang}: the label of #{name} should read #{strings.dig("form", name).inspect}, it reads #{label.text.strip.inspect}" if label && !label.text.include?(strings.dig("form", name))
    end
    area = form.at_css("textarea[name='messaggio']")
    errors << "#{lang}: the textarea must have rows=\"5\", it has #{area && area["rows"].inspect}" unless area && area["rows"] == "5"
    trap = form.at_css("input[name='_gotcha']")
    if trap
      errors << "#{lang}: the honeypot must be type=\"text\"" unless trap["type"] == "text"
      errors << "#{lang}: the honeypot must have tabindex=\"-1\"" unless trap["tabindex"] == "-1"
      errors << "#{lang}: the honeypot must have autocomplete=\"off\"" unless trap["autocomplete"] == "off"
      errors << "#{lang}: the honeypot must be hidden" unless trap.has_attribute?("hidden")
      errors << "#{lang}: the honeypot must have no label and no id (nothing for a person to find)" if trap["id"]
    else
      errors << "#{lang}: no honeypot <input name=\"_gotcha\">"
    end
    names = form.css("input,textarea,select").map { |n| n["name"] }
    extra = names - %w[nome email telefono messaggio _gotcha]
    errors << "#{lang}: the form has fields Soshiki did not define: #{extra.inspect}" unless extra.empty?
    submit = form.css("button").to_a
    errors << "#{lang}: the form needs one <button type=\"submit\"> reading #{strings.dig("form", "send").inspect}" unless submit.size == 1 && submit[0]["type"] == "submit" && submit[0].text.strip == strings.dig("form", "send")
    errors << "#{lang}: the form must not load a script or frame" if form.css("script,iframe").any?
    # the privacy notice sits with the form and links the privacy page in this language
    privacy = lang == "it" ? "/it/privacy/" : "/privacy/"
    box = form.ancestors.find { |n| n["class"].to_s.split.include?("cform") }
    link = box && box.css("a[href]").find { |a| a["href"] == privacy }
    errors << "#{lang}: the form needs a privacy notice linking #{privacy} (inside .cform, under the form)" unless link
    notice = box && box.at_css(".cform__note")
    wanted = "#{strings.dig("form", "privacy_pre")} #{strings.dig("form", "privacy_link")}."
    errors << "#{lang}: the privacy notice (.cform__note) is missing" unless notice
    if notice
      errors << "#{lang}: the privacy notice should read #{wanted.inspect}, it reads #{notice.text.gsub(/\s+/, " ").strip.inspect}" unless notice.text.gsub(/\s+/, " ").strip == wanted
      literal = lang == "it" ? "Leggi la nostra informativa sulla privacy." : "Read our privacy policy."
      errors << "#{lang}: the privacy notice should read #{literal.inspect}" unless notice.text.gsub(/\s+/, " ").strip == literal
      errors << "#{lang}: the privacy notice must not claim consent (accept/accetti): the policy is still a draft" if notice.text =~ /accept|accett/i
    end
    errors << "#{lang}: the privacy notice text in _data/i18n/#{lang}.yml must not claim consent (accept/accetti)" if strings["form"].values_at("privacy_pre", "privacy_link").join(" ") =~ /accept|accett/i
    errors << "#{lang}: the optional marker should be lowercase, it is #{strings.dig("form", "optional").inspect}" unless strings.dig("form", "optional") == strings.dig("form", "optional").downcase
    errors << "#{lang}: the privacy notice must come after the form" if link && form.xpath("following::a").none? { |a| a == link }
  end

  # --- booking: a link-out to booking_url, primary button
  button = main.css("a.btn--solid").find { |a| a["href"] == booking }
  errors << "#{lang}: the booking button (a.btn--solid -> #{booking}) is missing from the page body" unless button
  errors << "#{lang}: the booking button should read #{strings["book"].inspect}" if button && button.text.strip != strings["book"]

  # --- direct contacts: links AND selectable text
  phone = company["phone"]
  digits = phone.delete(" ")
  wa = "https://wa.me/#{digits.delete("+")}"
  errors << "#{lang}: no WhatsApp link #{wa}" unless hrefs.include?(wa)
  errors << "#{lang}: no tel: link tel:#{digits}" unless hrefs.include?("tel:#{digits}")
  errors << "#{lang}: no mailto: link mailto:#{company["email"]}" unless hrefs.include?("mailto:#{company["email"]}")
  errors << "#{lang}: the phone number #{phone} must be visible text" unless text.include?(phone)
  errors << "#{lang}: the email #{company["email"]} must be visible text" unless text.include?(company["email"])
  errors << "#{lang}: the address must read #{company["locality"]}, #{company["postal_code"]}" unless text.include?("#{company["locality"]}, #{company["postal_code"]}")
  errors << "#{lang}: the contact page must stay indexable (no robots noindex)" if page.at_css("meta[name='robots']")
  errors
end

# The two legal drafts: bannered, noindex, outside the sitemap, only known facts.
def contact_legal_pages(ctx)
  site_dir = ctx.site_dir
  %w[privacy cookie].each do |legal|
    fail_list!(legal_page_errors("en", legal, "#{site_dir}/#{legal}/index.html"), "the English #{legal} draft is wrong (see the list above)")
    fail_list!(legal_page_errors("it", legal, "#{site_dir}/it/#{legal}/index.html"), "the Italian #{legal} draft is wrong (see the list above)")
  end
  # One sitemap, at the root, with both languages (the `sitemap` area asserts it in full).
  sitemap = "#{site_dir}/sitemap.xml"
  text = Checks::Site.read(sitemap)
  text.include?("/contact/</loc>") || fail!("#{sitemap} does not list /contact/: the contact page must be in the sitemap")
  text.include?("/it/contatti/</loc>") || fail!("#{sitemap} does not list /it/contatti/: the Italian contact page must be in the sitemap")
  ["/privacy/", "/cookie/", "/it/privacy/", "/it/cookie/"].each do |hit|
    fail!("#{sitemap} lists #{hit}: a draft legal page must not be in the sitemap (sitemap: false)") if text.include?("#{hit}</loc>")
  end
  pass "privacy + cookie drafts (EN + IT): noindex, bannered, out of the sitemap, company facts and services listed neutrally, every other section marked 'to be completed', no invented duration or legal basis; the contact pages are in the sitemap"

  # The footer's bottom bar links both legal pages, in the language of the page.
  [["en", ctx.en_home, "/privacy/", "/cookie/"], ["it", ctx.it_home, "/it/privacy/", "/it/cookie/"],
   ["en", "#{site_dir}/contact/index.html", "/privacy/", "/cookie/"], ["it", "#{site_dir}/it/contatti/index.html", "/it/privacy/", "/it/cookie/"]].each do |_lang, page, privacy, cookie|
    footer = footer_of(page)
    footer.include?("href=\"#{privacy}\"") || fail!("the <footer> of #{page} does not link #{privacy}")
    footer.include?("href=\"#{cookie}\"") || fail!("the <footer> of #{page} does not link #{cookie}")
  end
  pass "the footer links the Privacy and Cookie pages in both languages"
end

def legal_page_errors(lang, id, file)
  errors = []
  page = load_file(file)
  main = page.at_css("main")
  text = main.text.gsub(/\s+/, " ")
  company = YAML.load_file("_data/site_meta.yml").fetch("company")
  robots = page.css("meta[name='robots']").map { |m| m["content"] }
  errors << "#{lang}/#{id}: <meta name=\"robots\" content=\"noindex\"> is missing (a draft must not be indexed), found #{robots.inspect}" unless robots == ["noindex"]
  banner = lang == "it" ? "Bozza — il testo legale sarà fornito da Monte del Gallo prima del lancio" : "Draft — legal text to be provided by Monte del Gallo before launch"
  errors << "#{lang}/#{id}: the draft banner #{banner.inspect} is missing" unless text.include?(banner)
  errors << "#{lang}/#{id}: the banner must be an element with role=\"note\" (class draft)" unless main.at_css(".draft[role='note']")
  facts_list = [company["name"], company["vat"], company["email"], "#{company["locality"]} #{company["postal_code"]}"]
  facts_list.each do |fact|
    errors << "#{lang}/#{id}: the known fact #{fact.inspect} (data controller) is missing" unless text.include?(fact)
  end
  %w[Soshiki].each { |w| errors << "#{lang}/#{id}: the processor #{w} is not listed" unless text.include?(w) }
  errors << "#{lang}/#{id}: the 'to be completed' marker is missing for the processors still unknown" unless main.css(".tbd").size >= 2
  # Every section but the company facts (the first h2) carries a to-be-completed marker.
  body = main.at_css(".project__body")
  sections = []
  body.children.each do |node|
    if node.element? && node.name == "h2" then sections << [node.text.strip, []]
    elsif sections.last then sections.last[1] << node
    end
  end
  errors << "#{lang}/#{id}: the page needs the company facts and at least 2 more sections, it has #{sections.size} h2 section(s)" if sections.size < 3
  sections.drop(1).each do |heading, nodes|
    errors << "#{lang}/#{id}: the section #{heading.inspect} has no .tbd marker (everything but the company facts is still to be provided)" unless nodes.any? { |n| n.element? && (n["class"].to_s.split.include?("tbd") || n.at_css(".tbd")) }
  end
  facts = sections.first && sections.first[1].map(&:text).join(" ").gsub(/\s+/, " ")
  errors << "#{lang}/#{id}: the first section must list the company facts (name, VAT, address, email)" unless facts && facts_list.all? { |f| facts.include?(f) }
  # No legal characterisation: neutral fact lists only.
  characterisation = text.scan(/data controller|controller of|on behalf of|set their own|titolare del trattamento|responsabil[ei] del trattamento|per conto del sito|propri cookie/i)
  errors << "#{lang}/#{id}: legal characterisation #{characterisation.first.inspect} (the placeholder lists facts, it does not qualify anyone legally)" unless characterisation.empty?
  # Nothing invented: no retention period, no legal basis article, no number of days or years.
  invented = text.scan(/\b(\d+\s*(giorni|days|mesi|months|anni|years)|art\.?\s*\d+|GDPR|Reg(olamento)?\.?\s*\(?UE\)?)/i)
  errors << "#{lang}/#{id}: invented legal detail #{invented.flatten.compact.first.inspect}: the placeholder may only state known facts" unless invented.empty?
  stores = text.scan(/stores nothing on your device|non salva nulla/i)
  errors << "#{lang}/#{id}: #{stores.first.inspect} is a claim nobody verified (cookieless is not storage-less): say only that the analytics sets no cookie" unless stores.empty?
  errors << "#{lang}/#{id}: a processor 'to be completed' must not state a retention period or a legal basis" if text =~ /retention period of|legal basis is|base giuridica è/i
  errors
end
