#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates, ONCE, the committed brand rasters of the site (no image tooling runs in CI):
#
#   assets/img/share/default-en.png, default-it.png   1200x630 share cards (Open Graph / Twitter)
#   favicon.ico                                       16 + 32, from favicon.svg
#   apple-touch-icon.png (180), icon-192.png, icon-512.png   the mark on a solid background
#
# Run it again, and commit the files, when the logo or the tagline changes:
#
#   PYTHON=/path/to/python3 ruby script/make-share-images.rb
#
# THE LOGO IS ONE FILE TO SWAP. Today it is the mountain mark, the path of the `mdg-mark`
# symbol in _includes/icons.html (this script reads it from there, so the header, the cards
# and the icons cannot drift apart). favicon.svg is the same mark, hand-kept (it carries a
# dark-mode colour), and is what the browsers use. When the gallo logo arrives: replace the
# `mdg-mark` symbol, favicon.svg and MARK_PATH below (one path), and run this script.
#
# Needs: `rsvg-convert` (librsvg), ImageMagick 7 (`magick`, only to pack the .ico and the
# palette PNG), and python3 with fonttools, brotli and uharfbuzz
# (`pip install fonttools brotli uharfbuzz`, in a venv: PYTHON=<venv>/bin/python3).
# The text is NOT drawn with a system font: it is shaped (kerning included) by HarfBuzz from
# the site's own fonts (assets/fonts/*.woff2: Archivo 800 for the name, Hanken Grotesk 500 for
# the tagline, IBM Plex Mono 500 for the address) and written into the card as vector outlines,
# so the result does not depend on the fonts installed on the machine that runs this.

require "fileutils"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)
Dir.chdir(ROOT)

# Foundry tokens (_sass/foundry/_tokens.scss).
BG = "#EEF1EF"
INK = "#0E1A14"
INK2 = "#33463D"
MUTED = "#5C6B64"
EMERALD = "#0A6B45"
EMERALD_XL = "#49D39A"

RANGE_PATH = "M0 200 L150 70 L250 130 L380 40 L470 110 L600 25 L700 120 L820 60 L930 125 L1050 55 L1140 115 L1200 80 L1200 200 Z"

icons = File.read("_includes/icons.html", encoding: "utf-8")
MARK_PATH = icons[/<symbol id="mdg-mark"[^>]*><path[^>]*\sd="([^"]+)"/, 1] or abort "cannot read the mdg-mark symbol from _includes/icons.html"

def run(*cmd, env: {})
  system(env, *cmd) or abort "failed: #{cmd.join(" ")}"
end

TEXT_PY = <<~PY
  # stdin: JSON list of {font, weight, size, text, x, y, anchor, tracking}; stdout: JSON list of SVG path data.
  import io, json, sys
  import uharfbuzz as hb
  from fontTools.ttLib import TTFont
  from fontTools.pens.svgPathPen import SVGPathPen
  from fontTools.pens.transformPen import TransformPen

  fonts = {}
  def load(path, weight):
      key = (path, weight)
      if key not in fonts:
          tt = TTFont(path)
          tt.flavor = None
          buf = io.BytesIO()
          tt.save(buf)
          font = hb.Font(hb.Face(hb.Blob(buf.getvalue())))
          if weight:
              font.set_variations({"wght": weight})
          fonts[key] = (font, font.face.upem)
      return fonts[key]

  out = []
  for job in json.load(sys.stdin):
      font, upem = load(job["font"], job.get("weight"))
      buf = hb.Buffer()
      buf.add_str(job["text"])
      buf.guess_segment_properties()
      hb.shape(font, buf, {"kern": True, "liga": True})
      scale = job["size"] / upem
      track = job.get("tracking", 0)
      width = sum(p.x_advance * scale + track for p in buf.glyph_positions) - track
      x = job["x"] - (width if job.get("anchor") == "end" else 0)
      pen = SVGPathPen(None, ntos=lambda v: ("%.2f" % v).rstrip("0").rstrip("."))
      for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
          tp = TransformPen(pen, (scale, 0, 0, -scale, x + pos.x_offset * scale, job["y"] - pos.y_offset * scale))
          font.draw_glyph_with_pen(info.codepoint, tp)
          x += pos.x_advance * scale + track
      out.append(pen.getCommands())
  json.dump(out, sys.stdout)
PY

# SVG path data for each text job (see TEXT_PY).
def text_paths(jobs)
  require "json"
  require "open3"
  out, status = Open3.capture2(ENV.fetch("PYTHON", "python3"), "-c", TEXT_PY, stdin_data: JSON.generate(jobs))
  abort "text shaping failed (pip install fonttools brotli uharfbuzz; set PYTHON to that python3)" unless status.success?
  JSON.parse(out)
end

def render_svg(svg, png, width:, height:)
  run("rsvg-convert", "-w", width.to_s, "-h", height.to_s, "-o", png, svg)
end

def mark_svg(path, size, color, background: nil)
  bg = background ? %(<rect width="#{size}" height="#{size}" fill="#{background}"/>) : ""
  # the mark spans 22 of its 24 units; on a solid icon it takes 60% of the side (safe zone).
  scale = background ? size * 0.60 / 24.0 : size / 24.0
  off = (size - 24 * scale) / 2.0
  %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}">#{bg}<g transform="translate(#{off} #{off}) scale(#{scale})"><path fill="#{color}" d="#{path}"/></g></svg>)
end

# One line per sentence ("Custom software, automation and AI." / "Built in Rome.").
def tagline_lines(tagline) = tagline.split(/(?<=[.!?])\s+/)

FONT_DIR = File.join(ROOT, "assets/fonts")

def card_svg(title, tagline)
  w = 1200
  h = 630
  grid = (0..w).step(40).map { |x| %(<path d="M#{x} 0V#{h}"/>) }.join + (0..h).step(40).map { |y| %(<path d="M0 #{y}H#{w}"/>) }.join
  display = File.join(FONT_DIR, "archivo-latin-wght-normal.woff2")
  body = File.join(FONT_DIR, "hanken-grotesk-latin-wght-normal.woff2")
  mono = File.join(FONT_DIR, "ibm-plex-mono-latin-500-normal.woff2")
  jobs = [
    { font: display, weight: 800, size: 92, text: title, x: 228, y: 178, tracking: -1.5, fill: INK },
    { font: mono, size: 24, text: "MONTEDELGALLO.COM", x: w - 76, y: 62, anchor: "end", tracking: 1.5, fill: MUTED }
  ]
  tagline_lines(tagline).each_with_index do |line, i|
    jobs << { font: body, weight: 500, size: 46, text: line, x: 80, y: 300 + i * 62, fill: INK2 }
  end
  text = text_paths(jobs).zip(jobs).map { |d, job| %(<path fill="#{job[:fill]}" d="#{d}"/>) }.join("\n  ")
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}">
      <rect width="#{w}" height="#{h}" fill="#{BG}"/>
      <g stroke="#{INK}" stroke-opacity="0.055" stroke-width="1" fill="none">#{grid}</g>
      <g transform="translate(0 400) scale(1 1.15)"><path fill="#{EMERALD}" fill-opacity="0.22" transform="translate(0 -22)" d="#{RANGE_PATH}"/></g>
      <g transform="translate(0 400) scale(1 1.15)"><path fill="#{EMERALD}" d="#{RANGE_PATH}"/></g>
      <rect y="#{h - 10}" width="#{w}" height="10" fill="#{INK}"/>
      <g transform="translate(76 73) scale(5)"><path fill="#{EMERALD}" d="#{MARK_PATH}"/></g>
      #{text}
    </svg>
  SVG
end

Dir.mktmpdir("mdg-share") do |tmp|
  meta = YAML.load_file("_data/site_meta.yml", aliases: true)
  title = YAML.load_file("_config.yml")["title"]
  FileUtils.mkdir_p("assets/img/share")

  %w[en it].each do |lang|
    tagline = meta.dig(lang, "tagline") or abort "_data/site_meta.yml #{lang}.tagline is missing"
    svg = File.join(tmp, "card-#{lang}.svg")
    File.write(svg, card_svg(title, tagline))
    raw = File.join(tmp, "card-#{lang}.png")
    out = "assets/img/share/default-#{lang}.png"
    render_svg(svg, raw, width: 1200, height: 630)
    run("magick", raw, "-strip", "-colors", "256", "PNG8:#{out}")
    puts "wrote #{out}"
  end

  # Icons: the mark on a solid background (iOS ignores transparency).
  { "apple-touch-icon.png" => 180, "icon-192.png" => 192, "icon-512.png" => 512 }.each do |name, size|
    svg = File.join(tmp, "#{size}.svg")
    File.write(svg, mark_svg(MARK_PATH, size, EMERALD, background: BG))
    render_svg(svg, name, width: size, height: size)
    puts "wrote #{name}"
  end

  # favicon.ico: 16 + 32, transparent, from the same mark.
  pngs = [16, 32].map do |size|
    svg = File.join(tmp, "ico#{size}.svg")
    File.write(svg, mark_svg(MARK_PATH, size, EMERALD))
    png = File.join(tmp, "ico#{size}.png")
    render_svg(svg, png, width: size, height: size)
    png
  end
  run("magick", *pngs, "favicon.ico")
  puts "wrote favicon.ico"
end
