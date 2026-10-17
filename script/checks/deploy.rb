# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "socket"
require "tmpdir"
require "yaml"

# The deploy pipeline (Cloudflare Pages, Direct Upload from GitHub Actions) and the launch kit.
#
#   - .github/workflows/build.yml: the `build` job builds, runs script/check-build.sh and both
#     Lighthouse runs, and only then uploads the production `_site` as an artifact; the `deploy`
#     job `needs: build`, downloads that artifact and uploads it with the official wrangler-action
#     (`pages deploy _site`). Production = the branch `main` only (environment, --branch from the
#     ref, never hard-coded); every other branch is a preview. One deploy at a time per ref
#     (`concurrency`), least-privilege `permissions`, and a post-deploy step that asserts the
#     headers of the deployed URL (CSP everywhere, noindex on *.pages.dev).
#   - every `uses:` is pinned (a version tag or a commit SHA, never a branch); wrangler is pinned.
#   - no secret value anywhere in the repository (the token and the account id are GitHub
#     secrets; the workflow only names them).
#   - the built /_headers says `X-Robots-Tag: noindex` for the *.pages.dev hosts (the production
#     alias and the per-deployment URLs); previews are noindex by Cloudflare itself.
#   - deploy/ is not published, deploy/cloudflare/README.md documents the Pages project.
#   - tasks/launch-runbook.md names every external dependency and has the cutover and rollback.
#   - script/smoke-redirects.sh works: it passes against the built site served with its
#     _headers/_redirects (script/serve-built-site.py) and FAILS on a wrong redirect, on a
#     missing page and on a site that does not answer.

DEPLOY_WORKFLOW = ".github/workflows/build.yml"
DEPLOY_README = "deploy/cloudflare/README.md"
DEPLOY_RUNBOOK = "tasks/launch-runbook.md"
DEPLOY_SMOKE = "script/smoke-redirects.sh"
DEPLOY_PINNED = /@(v\d+(\.\d+){0,2}|\h{40})\z/
DEPLOY_SECRET_PATTERNS = {
  "a Cloudflare token or account id assigned a literal value" => /CLOUDFLARE_(API_TOKEN|ACCOUNT_ID)["']?\s*[:=]\s*["']?(?!\$\{\{)[A-Za-z0-9_-]{16,}/,
  "a Cloudflare API token (cfut_/cfat_ prefix)" => /\bcf(ut|at)_[A-Za-z0-9]{20,}/,
  "a GitHub token" => /\b(ghp|gho|ghs|ghu|github_pat)_[A-Za-z0-9_]{20,}/,
  "a bearer token" => /Bearer\s+[A-Za-z0-9._-]{30,}/,
  "a private key" => /-----BEGIN [A-Z ]*PRIVATE KEY-----/
}.freeze

# Words the runbook must contain, grouped by what they prove.
DEPLOY_RUNBOOK_TERMS = {
  "the five parts of the plan" => ["Prima del lancio", "Account esterni", "WordPress", "Cutover", "Verifiche post-lancio", "Rollback"],
  "the content gates" => ["privacy", "cookie", "Careers", "Digital signage", "tasks/seo-meta-review.md", "Edoardo", "Claudio", "Giuseppe", "sameAs", "logo del gallo"],
  "GitHub and Cloudflare" => ["CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "Pages: Edit", "site/foundation-home", "main", "pull request", "Direct Upload"],
  "Plausible" => ["Plausible", "book_call_click", "contact_submit", "download_click", "Business"],
  "Search Console" => ["Search Console", "TXT", "sitemap.xml"],
  "WordPress export and backfill" => ["WXR", "tasks/wp-inventory.json", "old.montedelgallo.com", "30 giorni"],
  "the cutover" => ["TTL", "HTTPS", "dominio personalizzato"],
  "the post-launch checks" => ["script/smoke-redirects.sh", "curl -I", "_headers", "X-Robots-Tag", "Soshiki", "404"],
  "the rollback" => ["old.montedelgallo.com", "DNS"]
}.freeze

def check_deploy(ctx)
  section "Asserting the deploy pipeline and the launch kit"

  workflow = YAML.safe_load(Checks::Site.read(DEPLOY_WORKFLOW)) || {}
  fail_list!(deploy_workflow_errors(workflow), "#{DEPLOY_WORKFLOW}: the deploy job is wrong (see the list above)")
  pass "#{DEPLOY_WORKFLOW}: `deploy` needs `build` (which checks, runs Lighthouse, then uploads the production _site), pushes only, production = main only, one deploy per ref, least-privilege permissions, headers verified after the deploy"

  fail_list!(deploy_lighthouse_errors, "the Lighthouse assertions are optimistic (see the list above)")
  pass "both Lighthouse configs assert the median run (a score below the threshold in most runs fails, not only in all of them)"

  fail_list!(deploy_pin_errors(workflow), "an action or tool is not pinned (see the list above)")
  pass "every `uses:` is pinned to a version tag or a commit SHA, and wrangler to an exact version"

  fail_list!(deploy_secret_errors, "a secret value is in the repository (see the list above)")
  pass "no token, key or account id value in any tracked or new file: the workflow only names the two GitHub secrets"

  fail_list!(deploy_headers_errors(ctx.site_dir), "#{ctx.site_dir}/_headers does not noindex *.pages.dev (see the list above)")
  pass "#{ctx.site_dir}/_headers: X-Robots-Tag noindex for https://:project.pages.dev/* and https://:version.:project.pages.dev/* (previews are noindex by Cloudflare itself)"

  fail_list!(deploy_readme_errors, "#{DEPLOY_README} is wrong (see the list above)")
  pass "deploy/ is excluded from the site and #{DEPLOY_README} documents the Pages project, the token scope and the secrets"

  fail_list!(deploy_runbook_errors, "#{DEPLOY_RUNBOOK} is incomplete (see the list above)")
  pass "#{DEPLOY_RUNBOOK}: content gates, external accounts, WordPress export + backfill, cutover, post-launch checks and rollback are all there"

  fail_list!(deploy_smoke_errors(ctx.site_dir), "#{DEPLOY_SMOKE} is wrong (see the list above)")
  pass "#{DEPLOY_SMOKE}: passes on the built site, fails on a wrong redirect, on a missing page and on a dead server"
end

# ---- the workflow --------------------------------------------------------------------------------

def deploy_workflow_errors(workflow)
  jobs = workflow["jobs"] || {}
  build = jobs["build"] || {}
  deploy = jobs["deploy"]
  return ["there is no `deploy` job"] unless deploy

  errors = []
  errors << "`deploy` must declare needs: build (it may only run after the check and Lighthouse), it has #{deploy["needs"].inspect}" unless Array(deploy["needs"]).include?("build")

  steps = build["steps"] || []
  index = ->(&matcher) { steps.index { |s| matcher.call(s) } }
  check_at = index.call { |s| s["run"].to_s.include?("script/check-build.sh") }
  lhci_at = steps.each_index.select { |i| steps[i]["run"].to_s.include?("autorun") }
  upload_at = index.call { |s| s["uses"].to_s.start_with?("actions/upload-artifact@") && s.dig("with", "path").to_s.strip == "_site" }
  if check_at.nil? || lhci_at.size < 2 || upload_at.nil?
    errors << "the `build` job must run script/check-build.sh, both Lighthouse runs (autorun) and an actions/upload-artifact step for `_site`"
  else
    errors << "the `_site` artifact must be uploaded AFTER the check and both Lighthouse runs (a failed gate must leave nothing to deploy)" unless upload_at > check_at && upload_at > lhci_at.max
    upload = steps[upload_at]["with"] || {}
    errors << "the `_site` upload must not run `if: always()` (a failed gate must leave nothing to deploy)" if steps[upload_at]["if"]
    download = (deploy["steps"] || []).find { |s| s["uses"].to_s.start_with?("actions/download-artifact@") }
    if download.nil?
      errors << "`deploy` must download the artifact with actions/download-artifact"
    else
      errors << "`deploy` downloads #{download.dig("with", "name").inspect}, `build` uploads #{upload["name"].inspect}" unless download.dig("with", "name") == upload["name"]
      errors << "`deploy` must download the artifact into `_site`" unless download.dig("with", "path").to_s.strip == "_site"
    end
  end
  reports = steps.find { |s| s["uses"].to_s.start_with?("actions/upload-artifact@") && s.dig("with", "path").to_s.include?(".lighthouseci") }
  errors << "the build job must upload .lighthouseci/ with `if: always()` (a failed run needs its reports)" unless reports && reports["if"].to_s.include?("always()")
  errors << "the build job must build with JEKYLL_ENV=production (the artifact IS the production site)" unless build.dig("env", "JEKYLL_ENV") == "production"

  condition = deploy["if"].to_s
  errors << "`deploy` must run on pushes only (a pull request from a fork has no secrets; a same-repo branch is already deployed by its push), `if` is #{condition.inspect}" unless condition.include?("github.event_name == 'push'")

  environment = deploy["environment"]
  env_name = environment.is_a?(Hash) ? environment["name"].to_s : environment.to_s
  unless env_name.include?("refs/heads/main") && env_name.include?("production") && env_name.include?("preview")
    errors << "the environment must be `production` for refs/heads/main and `preview` for every other ref, it is #{env_name.inspect}"
  end

  errors << "`deploy` needs a `concurrency` group (two deploys of one ref must not overlap)" unless deploy.dig("concurrency", "group").to_s.include?("github.ref")

  top = workflow["permissions"] || {}
  errors << "the workflow-level permissions must be exactly contents: read, they are #{top.inspect}" unless top == { "contents" => "read" }
  granted = deploy["permissions"]
  if granted.nil?
    errors << "`deploy` must declare its own permissions"
  else
    extra = granted.reject { |name, level| (name == "contents" && level == "read") || (name == "deployments" && level == "write") }
    errors << "`deploy` may only have contents: read and deployments: write, it also has #{extra.inspect}" unless extra.empty?
  end

  action = (deploy["steps"] || []).find { |s| s["uses"].to_s.start_with?("cloudflare/wrangler-action@") }
  if action.nil?
    errors << "`deploy` must use the official cloudflare/wrangler-action"
  else
    with = action["with"] || {}
    command = with["command"].to_s
    errors << "the deploy command must be `pages deploy _site --project-name=... --branch=...`, it is #{command.inspect}" unless command.match?(/\Apages deploy _site\b/) && command.include?("--project-name=") && command.include?("--branch=")
    errors << "--branch must come from the ref (so `main` is production and the rest are previews), never be hard-coded: #{command.inspect}" if command.match?(/--branch=(main|master|production)\b/) || !command.match?(/--branch=\S*(steps\.|github\.|\$)/)
    errors << "apiToken must be secrets.CLOUDFLARE_API_TOKEN" unless with["apiToken"].to_s.include?("secrets.CLOUDFLARE_API_TOKEN")
    errors << "accountId must be secrets.CLOUDFLARE_ACCOUNT_ID" unless with["accountId"].to_s.include?("secrets.CLOUDFLARE_ACCOUNT_ID")
  end

  verify = (deploy["steps"] || []).map { |s| s["run"].to_s }.join("\n").downcase
  errors << "`deploy` must verify the headers of the deployed URL (content-security-policy, x-robots-tag noindex) after the deploy" unless verify.include?("x-robots-tag") && verify.include?("content-security-policy")
  errors
end

def deploy_lighthouse_errors
  %w[.lighthouserc.json .lighthouserc.desktop.json].flat_map do |file|
    assertions = JSON.parse(Checks::Site.read(file)).dig("ci", "assert", "assertions") || {}
    errors = assertions.reject { |_, (_, options)| options["aggregationMethod"] == "median-run" }.keys.map { |name| "#{file}: #{name} must set aggregationMethod median-run" }
    errors << "#{file} asserts nothing" if assertions.empty?
    errors
  end
end

def deploy_pin_errors(workflow)
  errors = []
  (workflow["jobs"] || {}).each do |job_name, job|
    (job["steps"] || []).each do |step|
      uses = step["uses"].to_s
      next if uses.empty?

      errors << "#{job_name}: `uses: #{uses}` is not pinned to a version tag (@v1, @v1.2.3) or a 40-character commit SHA" unless uses.match?(DEPLOY_PINNED)
      next unless uses.start_with?("cloudflare/wrangler-action@")

      version = step.dig("with", "wranglerVersion").to_s
      errors << "#{job_name}: wranglerVersion must be an exact version (4.x.y), it is #{version.inspect}" unless version.match?(/\A\d+\.\d+\.\d+\z/)
    end
  end
  errors
end

# ---- secrets ---------------------------------------------------------------------------------------

def deploy_secret_errors
  files, status = Open3.capture2("git", "ls-files", "-co", "--exclude-standard")
  return ["git ls-files failed"] unless status.success?

  errors = []
  files.split("\n").each do |path|
    next unless File.file?(path)

    text = File.binread(path)
    next if text.include?("\0")

    text = text.force_encoding("UTF-8").scrub
    DEPLOY_SECRET_PATTERNS.each do |what, pattern|
      match = text[pattern]
      errors << "#{path}: looks like #{what} (#{match[0, 40].inspect}...)" if match
    end
  end
  errors
end

# ---- headers, README ---------------------------------------------------------------------------------

def deploy_headers_errors(site_dir)
  rules = {}
  current = nil
  File.read(File.join(site_dir, "_headers"), encoding: "utf-8").each_line do |raw|
    line = raw.chomp
    next if line.strip.empty? || line.start_with?("#")

    if line.match?(/\A\S/)
      current = rules[line] = {}
    elsif current
      name, value = line.strip.split(/:\s*/, 2)
      current[name] = value
    end
  end
  ["https://:project.pages.dev/*", "https://:version.:project.pages.dev/*"].filter_map do |host_rule|
    "#{host_rule} must set X-Robots-Tag: noindex, it has #{rules[host_rule].inspect}" unless rules[host_rule] && rules[host_rule]["X-Robots-Tag"] == "noindex"
  end
end

def deploy_readme_errors
  errors = []
  excluded = Array(YAML.safe_load(Checks::Site.read("_config.yml"))["exclude"]).map { |e| e.to_s.chomp("/") }
  errors << "_config.yml `exclude` must list deploy/ (the server notes are not part of the site)" unless excluded.include?("deploy")
  return errors << "#{DEPLOY_README} is missing" unless File.file?(DEPLOY_README)

  text = Checks::Site.read(DEPLOY_README)
  ["Direct Upload", "Pages: Edit", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "montedelgallo", "noindex", "pages.dev", "Production branch", "custom domain"].each do |word|
    errors << "#{DEPLOY_README} does not mention #{word.inspect}" unless text.include?(word)
  end
  errors
end

def deploy_runbook_errors
  return ["#{DEPLOY_RUNBOOK} is missing"] unless File.file?(DEPLOY_RUNBOOK)

  text = Checks::Site.read(DEPLOY_RUNBOOK)
  errors = DEPLOY_RUNBOOK_TERMS.flat_map do |what, words|
    words.reject { |word| text.downcase.include?(word.downcase) }.map { |word| "#{DEPLOY_RUNBOOK} has no #{word.inspect} (#{what})" }
  end
  # Every goal the markup sends must be a goal the client is told to create.
  events = Checks::Site.grep_tree("data-track=\"", "_includes", except_ext: []).flat_map { |f| Checks::Site.read(f).scan(/data-track="([a-z_]+)"/).flatten }
  events.uniq.each { |event| errors << "#{DEPLOY_RUNBOOK} does not list the Plausible goal #{event.inspect} (the markup sends it)" unless text.include?(event) }
  errors << "#{DEPLOY_RUNBOOK} must not ask for an R2 bucket (the downloads are Soshiki and the repository)" if text.match?(/crea[^\n]*bucket|bucket R2 da creare/i)
  errors
end

# ---- the smoke script -------------------------------------------------------------------------------

def deploy_smoke_errors(site_dir)
  return ["#{DEPLOY_SMOKE} is missing"] unless File.file?(DEPLOY_SMOKE)

  errors = []
  errors << "#{DEPLOY_SMOKE} must be executable" unless File.executable?(DEPLOY_SMOKE)
  errors << "#{DEPLOY_SMOKE} must start with set -euo pipefail" unless Checks::Site.read(DEPLOY_SMOKE).include?("set -euo pipefail")
  return errors unless errors.empty?

  Dir.mktmpdir("smoke-site") do |broken|
    # A copy of the built site made of symlinks, except /_redirects (first rule re-pointed) and
    # without the About page: two defects the script has to find.
    Dir.children(site_dir).each do |entry|
      next if %w[_redirects about].include?(entry)

      File.symlink(File.expand_path(File.join(site_dir, entry)), File.join(broken, entry))
    end
    lines = File.readlines(File.join(site_dir, "_redirects"), chomp: true)
    first = lines.index { |l| l.match?(%r{\A/\S+ /\S+ 301\z}) }
    lines[first] = lines[first].sub(%r{ /\S+ 301\z}, " /definitely-not-here/ 301")
    File.write(File.join(broken, "_redirects"), lines.join("\n") + "\n")

    deploy_with_server(site_dir) do |url|
      out, status = Open3.capture2e(DEPLOY_SMOKE, url, site_dir)
      errors << "the script must pass on the intact built site, it exited #{status.exitstatus}:\n#{out.lines.last(8).join}" unless status.success?
    end
    deploy_with_server(broken) do |url|
      out, status = Open3.capture2e(DEPLOY_SMOKE, url, site_dir)
      errors << "the script must FAIL on a site with a wrong redirect and a missing page" if status.success?
      errors << "the script must name the wrong redirect (/definitely-not-here/) in its output" unless out.include?("definitely-not-here")
      errors << "the script must name the missing page (/about/) in its output" unless out.include?("/about/")
    end
  end
  closed = deploy_free_port
  _out, status = Open3.capture2e(DEPLOY_SMOKE, "http://127.0.0.1:#{closed}", site_dir)
  errors << "the script must FAIL when nothing answers" if status.success?
  _out, status = Open3.capture2e(DEPLOY_SMOKE)
  errors << "the script must exit non-zero without a base URL" if status.success?
  errors
end

def deploy_free_port
  server = TCPServer.new("127.0.0.1", 0)
  port = server.addr[1]
  server.close
  port
end

# Serves `dir` with script/serve-built-site.py on a free port while the block runs.
def deploy_with_server(dir)
  port = deploy_free_port
  pid = Process.spawn("python3", "script/serve-built-site.py", dir, port.to_s, out: File::NULL, err: File::NULL)
  begin
    60.times do
      TCPSocket.new("127.0.0.1", port).close
      break
    rescue Errno::ECONNREFUSED
      sleep 0.1
    end
    yield "http://127.0.0.1:#{port}"
  ensure
    Process.kill("TERM", pid)
    Process.wait(pid)
  end
end
