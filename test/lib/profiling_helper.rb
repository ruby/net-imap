# frozen_string_literal: true

module ProfilingHelper
  module_function

  def profile?            = ENV["NET_IMAP_PROFILE"] in /\A(1|t|true|on|yes)\z/i
  def start_profiler(...) = if profile? then start_profiler!(...) end
  def stop_profiler       = if profile? then stop_profiler!       end
  def stop_profiler!      = Vernier.stop_profile

  def maybe_profile(...)
    return unless $allowed_to_profile # set in benchmark context prelude
    profile_until_exit(...)
  end

  def profile_until_exit(...)
    return unless profile?
    start_profiler!(...)
    at_exit { stop_profiler }
  end

  def start_profiler!(name, **opts)
    require "vernier"
    require "fileutils"

    outdir = ENV.fetch("NET_IMAP_PROFILE_OUTDIR") {
      cache_dir = ENV.fetch("XDG_CACHE_HOME", File.join(Dir.home, ".cache"))
      File.join(cache_dir, "net-imap")
    }
    outfile = "prof-#{name}-#{Time.now.iso8601}.json.gz"
    out = File.join(outdir, outfile)

    FileUtils.mkdir_p outdir
    Vernier.start_profile(out:, **opts)
  end
end
