# frozen_string_literal: true

# Reporting: the PASS / FAIL lines and the shared assertions on files.
#
# Every check ends in one of two ways: `pass` prints a "PASS:" line, `fail!`
# prints a "FAIL:" line to stderr and stops the run with a non-zero exit.
# A check that collects several problems hands them to `fail_list!`, which
# prints them as a list first ("  - ...") and then the FAIL line.

module Checks
  module Report
    class << self
      # The scratch copy of the site that the fixture tests build. Its long
      # temporary path is shortened to <fixture> in every message.
      attr_accessor :fixture_root

      def scrub(message)
        root = fixture_root.to_s
        root.empty? ? message : message.gsub(root, "<fixture>")
      end
    end
  end

  module Helpers
    # A section header, like "==> Asserting the page shell".
    def section(title)
      puts "==> #{title}"
    end

    def pass(message)
      puts "PASS: #{Report.scrub(message.to_s)}"
    end

    def fail!(message)
      warn "FAIL: #{Report.scrub(message.to_s)}"
      exit 1
    end

    # Print every problem as a list item, then fail with `message`. Does
    # nothing when `errors` is empty, so a check can end with it unconditionally.
    def fail_list!(errors, message)
      return if errors.empty?

      warn errors.map { |error| "  - #{Report.scrub(error.to_s)}" }.join("\n")
      fail!(message)
    end

    # assert_file <path> <why-it-must-exist>: present and non-empty.
    def assert_file(path, why)
      fail!("#{path} is missing or empty (#{why})") unless File.size?(path)
      pass "#{path} exists"
    end

    # require_contains <path> <literal> <why>: the file contains the literal text
    # (fixed string, not a regex). No PASS line, for loops over many items that
    # print a single line of their own.
    def require_contains(path, needle, why)
      return if File.file?(path) && Site.read(path).include?(needle)

      fail!("#{path} does not contain '#{needle}' (#{why})")
    end

    # assert_contains: require_contains plus a PASS line.
    def assert_contains(path, needle, why)
      require_contains(path, needle, why)
      pass "#{path} contains #{needle}"
    end

    # The same file check on a regular expression (`grep -E`).
    def require_match(path, regex, message)
      fail!(message) unless File.file?(path) && Site.read(path).match?(regex)
    end
  end
end
