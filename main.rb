# frozen_string_literal: true

require "bundler/setup"

require "active_support/all"
require "fileutils"
require "rack"
require "securerandom"

ENV["MEGABYTES_PER_BLOCK"] ||= "1"
ENV["BLOCKS_PER_ITERATION"] ||= "100"
ENV["INTERVAL_IN_SECONDS"] ||= "60"

module DiskBench
  BLOCK_SIZE = ENV.fetch("MEGABYTES_PER_BLOCK").to_i.megabyte
  BLOCK = "\0" * BLOCK_SIZE

  def self.run(blocks: ENV.fetch("BLOCKS_PER_ITERATION").to_i)
    path = "diskbench-#{SecureRandom.hex(8)}.bin" # use unique files to avoid potential caching effects
    write_result = write_test(path:, blocks:)
    read_result = read_test(path:)

    { write: write_result, read: read_result, time_taken: write_result[:elapsed] + read_result[:elapsed] }
  ensure
    FileUtils.rm_f(path) if path
  end

  def self.write_test(blocks:, path:)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    bytes_written = 0

    File.open(path, "wb") do |file|
      blocks.times do
        file.write(BLOCK)
        bytes_written += BLOCK.bytesize
      end

      file.fsync # push to disk as far as the FS allows
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    {
      bytes_written:,
      elapsed:,
      bytes_per_second: bytes_written / elapsed,
      block_size: BLOCK_SIZE,
    }
  end

  def self.read_test(path:)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    bytes_read = 0

    File.open(path, "rb") do |f|
      while (chunk = f.read(1.megabyte))
        bytes_read += chunk.bytesize
      end
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    {
      bytes: bytes_read,
      elapsed: elapsed,
      bytes_per_second: bytes_read.to_f / elapsed,
      block_size: BLOCK_SIZE,
    }
  end
end

# Rack endpoint for prometheus metrics
class MetricsEndpoint
  HEADERS = { "Content-Type" => "text/plain" }.freeze
  RESPONSE_TEMPLATE = <<~METRICS
    # HELP disk_read_megabytes_per_second Disk read megabytes per second
    # TYPE disk_read_megabytes_per_second gauge
    disk_read_megabytes_per_second %<read_megabytes_per_second>s
    # HELP disk_write_megabytes_per_second Disk write megabytes per second
    # TYPE disk_write_megabytes_per_second gauge
    disk_write_megabytes_per_second %<write_megabytes_per_second>s
  METRICS

  def call(env)
    if env["PATH_INFO"] == "/metrics"
      return [503, HEADERS, ["Metrics not ready"]] unless ready?

      response = format(
        RESPONSE_TEMPLATE,
        read_megabytes_per_second: $disk_read_megabytes_per_second,
        write_megabytes_per_second: $disk_write_megabytes_per_second,
      )

      [200, HEADERS, [response]]
    else
      [404, HEADERS, ["Not Found"]]
    end
  end

  private

  def ready?
    $disk_read_megabytes_per_second && $disk_write_megabytes_per_second
  end
end

Thread.new do
  (1..).each do |i|
    result = DiskBench.run
    $disk_read_megabytes_per_second = (result[:read][:bytes_per_second] / 1.megabyte).round
    $disk_write_megabytes_per_second = (result[:write][:bytes_per_second] / 1.megabyte).round

    puts "iteration=#{i} time_taken=#{result[:time_taken]} read_megabytes_per_second=#{$disk_read_megabytes_per_second} write_megabytes_per_second=#{$disk_write_megabytes_per_second}" # rubocop:disable Layout/LineLength

    sleep ENV.fetch("INTERVAL_IN_SECONDS").to_i
  end
end
