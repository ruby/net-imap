# frozen_string_literal: true

desc "Generate CHANGELOG.md"
task "changelog:generate" do
  require "json"
  release_json = `gh api repos/ruby/net-imap/releases`
  releases = JSON.parse(release_json)
  entries = releases.map {|release|
    release.transform_keys!(&:to_sym)
    release => {name:, tag_name:, created_at:, body:}
    url = "https://github.com/ruby/net-imap/tree/#{tag_name}"
    date = created_at[0, 10]
    body = body.delete("\r").gsub(/^#/, "##")
    <<~ENTRY
      ## [#{name}](#{url}) (#{date})

      #{body}
    ENTRY
  }
  last_tag = releases.first[:tag_name]
  File.write("CHANGELOG.md", <<~CHANGELOG)
    # Changelog

    ## [Unreleased](https://github.com/ruby/net-imap/tree/HEAD)

    * ???

    **Full Changelog**: https://github.com/ruby/net-imap/compare/#{last_tag}...HEAD

    #{entries.join("\n")}
  CHANGELOG
end
