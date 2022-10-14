# frozen_string_literal: true

task :ghpages do
  docd   = ENV["RDOC_BRANCH"] or abort "Usage: rake ghpages RDOC_BRANCH=<git-ref>"
  pages  = ENV["RDOC_PAGES_BRANCH"] || "gh-pages"

  version = IO.popen(%w[git describe] << docd, &:read).chomp \
    and $?.success? && !version.empty? \
    or abort "ERROR: could not discover version."

  `git status --porcelain`.empty? or abort "ERROR: Working copy must be clean."

  when_writing "Preparing #{pages} branch" do
    sh "git", "switch", pages
    sh "git rev-parse @{u}"
  end

  when_writing "Updating #{pages} branch to #{docd} => #{version}" do
    # simulating `git merge -d theirs`
    sh "git", "reset", "--hard", docd
    sh "git reset --soft @{u}"
    sh "git rev-parse #{docd} > .git/MERGE_HEAD"
  end

  when_writing "Updating #{pages} branch with documentation from #{docd}" do
    # running inside another rake process, in case something important has
    # changed between the invocation branch and the documented branch.
    Bundler.with_original_env do
      sh "bundle check || bundle install"
      sh "bundle exec rake"
      sh "bundle exec rake rerdoc"
    end
    rm_rf "docs"
    mv    "doc", "docs"
    touch "docs/.nojekyll" # => skips default pages action build step
    sh "git add --force --all docs"
  end

  when_writing "Committing #{pages} changes for #{version}" do
    sh "git", "commit", "-m", "Generated rdoc html for #{version}"
    puts "*** Latest changes committed.  Deploy with 'git push origin HEAD'"
  end
end
