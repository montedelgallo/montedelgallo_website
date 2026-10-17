# frozen_string_literal: true

# Images: what makes a file a real, complete image, in one place.
#
# A file with the right name and the wrong content (an HTML error page saved by a
# failed download, an empty file) is a broken picture on the page, so look at the
# first bytes. A file that was cut short keeps those first bytes, so look at how
# it ends as well: each format says where it stops.

module Checks
  module Images
    PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].freeze
    PNG_END = "0000000049454e44ae426082" # length 0, "IEND", its CRC

    module_function

    # :jpeg, :png, :webp, or nil when the first bytes are none of them.
    def detect(path)
      head = File.binread(path, 12).to_s
      bytes = head.bytes
      if bytes[0, 3] == [0xFF, 0xD8, 0xFF] then :jpeg
      elsif bytes[0, 8] == PNG_SIGNATURE then :png
      elsif head.bytesize == 12 && head.byteslice(0, 4) == "RIFF" && head.byteslice(8, 4) == "WEBP" then :webp
      end
    end

    # Looks at the file and answers [kind, size, problem]: `problem` is nil when the
    # file is a complete JPEG, PNG or WEBP of at least `min_bytes`, else a sentence
    # that starts with `label` (default: the path).
    def inspect_file(path, min_bytes:, label: path)
      size = File.size?(path)
      return [nil, 0, "#{label} is missing or empty"] unless size

      kind = detect(path)
      unless kind
        hex = File.binread(path, 12).unpack1("H*")
        return [nil, size, "#{label} is not a JPEG, PNG or WEBP image (it starts with the bytes #{hex})"]
      end
      return [kind, size, "#{label} is only #{size} bytes: too small to be a real image"] if size < min_bytes

      problem =
        case kind
        when :webp # bytes 4-7: the size of everything after them, little-endian
          declared = File.binread(path, 4, 4).unpack1("V") + 8
          "#{label} is a damaged WEBP: its header says #{declared} bytes, the file has #{size} (cut short, or bytes added at the end)" unless declared == size
        when :jpeg # the last two bytes are the end-of-image marker
          "#{label} is a damaged JPEG: it does not end with the end-of-image marker (ffd9), so it was cut short" unless tail(path, 2) == "ffd9"
        when :png # the last 12 bytes are the IEND chunk
          "#{label} is a damaged PNG: it does not end with the IEND chunk, so it was cut short" unless tail(path, 12) == PNG_END
        end
      [kind, size, problem]
    end

    def tail(path, count)
      File.open(path, "rb") do |file|
        file.seek(-count, IO::SEEK_END)
        file.read(count).unpack1("H*")
      end
    end

    # [width, height] of a WebP file, read from its header (lossy VP8, lossless
    # VP8L or extended VP8X); nil when it is not one.
    def webp_dimensions(path)
      head = File.binread(path, 40) or return nil
      return nil unless head[0, 4] == "RIFF" && head[8, 4] == "WEBP"

      case head[12, 4]
      when "VP8 " then [head[26, 2].unpack1("v") & 0x3fff, head[28, 2].unpack1("v") & 0x3fff]
      when "VP8L"
        bits = head[21, 4].unpack1("V")
        [(bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1]
      when "VP8X"
        a = head[24, 3].unpack("C3")
        b = head[27, 3].unpack("C3")
        [a[0] + (a[1] << 8) + (a[2] << 16) + 1, b[0] + (b[1] << 8) + (b[2] << 16) + 1]
      end
    end
  end

  module Helpers
    # assert_real_image <public path of the image> <what it is>
    # The built file is a real, complete image of at least 4 KB, published once
    # (assets are shared at /assets/, never copied under /it/).
    def assert_real_image(public_path, what, root: SITE_DIR)
      file = "#{root}#{public_path}"
      fail!("#{file} is missing or empty: the build did not publish #{what}") unless File.size?(file)
      kind, size, problem = Images.inspect_file(file, min_bytes: 4096)
      fail!("#{problem}: #{what} is a real, complete image, not an HTML error page, a stub or a cut-short file") if problem
      fail!("the image #{public_path} was also written under /it/: images are shared at /assets/ (exclude_from_localization)") if File.exist?("#{root}/it#{public_path}")
      pass "#{file} is a complete #{kind.to_s.upcase} image (#{size} bytes), published once"
    end
  end
end
