# frozen_string_literal: true

# The Foundry design system: the compiled CSS and the self-hosted fonts.

# The patterns below read Sass's compressed output (sass.style in _config.yml):
# one line, no whitespace around braces.
FOUNDRY_TOKENS = [
  "--bg:#EEF1EF", "--surface:#F8FAF9", "--ink:#0E1A14", "--ink-2:#33463D",
  "--muted:#5C6B64", "--line:rgba(14,26,20,.14)", "--line-2:rgba(14,26,20,.28)",
  "--emerald:#0A6B45", "--emerald-l:#17A86C", "--emerald-xl:#49D39A",
  "--dark:#0C1712", "--dark-em:#0A5C3C"
].freeze

# The weights the design uses (plan Global Constraints). Archivo and Hanken
# Grotesk are variable fonts, so one face declares a weight RANGE; IBM Plex Mono
# is static, one face per weight. A face that declares the wrong weight (or none)
# makes the browser fake-bold or pick another file, and nothing errors.
FONT_WEIGHTS = [["Archivo", "700 900"], ["Hanken Grotesk", "400 700"], ["IBM Plex Mono", "500"], ["IBM Plex Mono", "600"]].freeze

def check_styles(ctx)
  section "Asserting the Foundry design system (compiled CSS + self-hosted fonts)"
  css_file = ctx.css
  assert_file css_file, "assets/css/main.scss was not compiled"
  css = Checks::Site.read(css_file)

  # The exact Foundry tokens from the plan's Global Constraints. This is a
  # fixed-string match on the compiled CSS, so the tokens must stay compact in
  # _sass/foundry/_tokens.scss (no space after the colon): Sass keeps custom
  # property values verbatim.
  FOUNDRY_TOKENS.each do |token|
    css.include?(token) ||
      fail!("#{css_file} is missing the Foundry token '#{token}' (value changed, or re-spaced in _tokens.scss?)")
  end
  pass "all #{FOUNDRY_TOKENS.size} Foundry tokens are present with their exact values"

  # Reduced motion (plan Review Focus): the pulsing status dots must stop. The
  # media query has to be there AND it has to switch animations and transitions
  # off, with !important, for EVERY element: the block's first selector must be
  # the universal `*` (as in `*, *::before, *::after`). A guard scoped to one
  # class would let the next animated element slip through.
  assert_contains css_file, "prefers-reduced-motion",
                  "motion guard missing: the pulsing dots would ignore the user's reduced-motion setting"
  css.match?(/prefers-reduced-motion: ?reduce\)\{\*(,[^{}]*)?\{animation:none ?!important;transition:none ?!important/) ||
    fail!("the prefers-reduced-motion block in #{css_file} must start with the universal selector (*) and turn animation and transition off with !important")
  pass "reduced-motion guard disables animations and transitions on every element"

  # Keyboard focus (AA): the emerald ring is about 2.7:1 on the dark bands, below
  # the 3:1 a focus indicator needs, so every dark band must lighten it by setting
  # --focus on itself. Those are the utility strip, the footer and the skip link,
  # and on the home the growth system (.stack), the Robotic Lab band (.rlab) and the final
  # call to action (.cta).
  %w[util foot skip stack rlab cta].each do |band|
    css.match?(/\.#{band}\{[^}]*--focus:var\(--emerald-xl\)/) ||
      fail!("the .#{band} rule in #{css_file} does not set --focus:var(--emerald-xl): the focus ring would be too faint on its dark background")
  end
  pass "dark bands (.util, .foot, .skip, .stack, .rlab, .cta) lighten the focus ring"

  # The committed light world: no dark-mode variants.
  if css.include?("prefers-color-scheme")
    fail!("#{css_file} contains a prefers-color-scheme block: Foundry is a single committed light world")
  end
  pass "no dark-mode block in the CSS"

  # Fonts are self-hosted: one @font-face per family at least, each with
  # font-display:swap, each pointing at a file that exists in the built site.
  # (A wrong path never errors: the browser silently shows a system font.)
  ["Archivo", "Hanken Grotesk", "IBM Plex Mono"].each do |family|
    css.match?(/@font-face\{[^}]*font-family:["']?#{family}["']?[;}]/) ||
      fail!("#{css_file} has no @font-face for '#{family}'")
  end
  faces = css.scan("@font-face").size
  swaps = css.scan("font-display:swap").size
  (faces >= 3 && faces == swaps) ||
    fail!("#{css_file} has #{faces} @font-face rule(s) but #{swaps} font-display:swap: every face needs font-display:swap")
  pass "@font-face declared for Archivo, Hanken Grotesk and IBM Plex Mono, all with font-display:swap"

  FONT_WEIGHTS.each do |family, weight|
    css.match?(/@font-face\{[^}]*font-family:["']?#{family}["']?;[^}]*font-weight:#{weight};/) ||
      fail!("#{css_file} has no @font-face for '#{family}' declaring font-weight:#{weight}")
  end
  pass "font weights pinned: Archivo 700-900, Hanken Grotesk 400-700, IBM Plex Mono 500 and 600"

  font_refs = css.scan(/url\([^)]*\.woff2[^)]*\)/).map { |ref| ref.delete("\"'").sub(/\Aurl\(/, "").sub(/\)\z/, "") }.uniq.sort
  fail!("#{css_file} references no .woff2 file") if font_refs.empty?
  css_dir = File.dirname(css_file)
  font_refs.each do |ref|
    font_path =
      case ref
      when %r{\Ahttps?://}, %r{\A//} then fail!("#{css_file} loads the font '#{ref}' from another origin: fonts must be self-hosted")
      when %r{\A/} then "#{ctx.site_dir}#{ref}"
      else File.join(css_dir, ref) # relative URLs resolve against the CSS file's own URL
      end
    fail!("#{css_file} points at the font '#{ref}', which is not in the built site (#{font_path})") unless File.size?(font_path)
    # A WOFF2 file starts with the four bytes "wOF2". A renamed TTF, or an HTML
    # error page saved under the font's name, has the right path and the wrong
    # content, and the browser silently falls back to a system font.
    File.binread(font_path, 4) == "wOF2" ||
      fail!("#{font_path} is not a WOFF2 file (it does not start with the wOF2 signature)")
  end
  # ...and every font file the site ships, referenced or not.
  font_files = Dir.glob("#{ctx.site_dir}/assets/fonts/*.woff2").sort
  fail!("no .woff2 file in #{ctx.site_dir}/assets/fonts/") if font_files.empty?
  font_files.each do |font_file|
    File.binread(font_file, 4) == "wOF2" ||
      fail!("#{font_file} is not a WOFF2 file (it does not start with the wOF2 signature)")
  end
  pass "every .woff2 referenced by the CSS exists in the built site and is a real WOFF2 file"

  # Hard constraint: nothing in the output may pull fonts from the Google Fonts
  # CDN (the design mockup does, so it is an easy mistake to copy over). Source
  # maps are skipped: they embed the SCSS source text, not runtime requests.
  hit = Checks::Site.text_files(ctx.site_dir).reject { |path| path.end_with?(".map") }
                    .find { |path| Checks::Site.read(path).match?(/fonts\.(googleapis|gstatic)\.com/) }
  fail!("the built site references the Google Fonts CDN: fonts must be self-hosted (assets/fonts/)") if hit
  pass "no Google Fonts CDN reference anywhere in the built site"
end
