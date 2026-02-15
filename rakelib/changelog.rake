# frozen_string_literal: true

desc "Generate CHANGELOG.md"
task "changelog:generate" do
  require "json"
  release_json = `gh api repos/ruby/net-imap/releases --paginate`
  releases = JSON.parse(release_json, symbolize_names: true)
    .sort_by { Gem::Version.new(_1[:tag_name].delete(?v)) }
  entries = releases.reverse_each.map {|release|
    release => {name:, tag_name:, created_at:, body:}
    url = "https://github.com/ruby/net-imap/tree/#{tag_name}"
    date = created_at[0, 10]
    body = body.delete("\r").strip
      .gsub(/^#/, "##")
      .gsub(/^<!-- Release notes generated .* -->$\n\n/, "")
    <<~ENTRY
      ## [#{name}](#{url}) (#{date})

      #{body}
    ENTRY
  }
  last_tag = releases.last[:tag_name]
  File.write("CHANGELOG.md", <<~CHANGELOG)
    # Changelog

    ## [Unreleased](https://github.com/ruby/net-imap/tree/HEAD)

    * ???

    **Full Changelog**: https://github.com/ruby/net-imap/compare/#{last_tag}...HEAD

    #{entries.join("\n\n")}
  CHANGELOG
end
