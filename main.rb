# frozen_string_literal: true

require "active_support/all"
require "fileutils"
require "rack"
require "securerandom"

module DiskBench
  BLOCK_SIZE = 1.megabyte
  BLOCK = "\0" * BLOCK_SIZE

  def self.run(blocks: 10)
    path = "diskbench-#{SecureRandom.hex(8)}.bin"
    write_result = write_test(path:, blocks:)
    read_result = read_test(path:)

    { write: write_result, read: read_result }
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
      op: "write",
      path:,
      bytes: bytes_written,
      seconds: elapsed,
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
      op: "read",
      path:,
      bytes: bytes_read,
      seconds: elapsed,
      bytes_per_second: bytes_read.to_f / elapsed,
      block_size: BLOCK_SIZE,
    }
  end
end

# Rack endpoint for prometheus metrics
class MetricsEndpoint
  HEADERS = { "Content-Type" => "text/plain" }.freeze
  RESPONSE_TEMPLATE = <<~METRICS
    # HELP disk_read_bytes_per_second Disk read bytes per second
    # TYPE disk_read_bytes_per_second gauge
    disk_read_bytes_per_second %<read_bytes_per_second>s
    # HELP disk_write_bytes_per_second Disk write bytes per second
    # TYPE disk_write_bytes_per_second gauge
    disk_write_bytes_per_second %<write_bytes_per_second>s
  METRICS

  def call(env)
    if env["PATH_INFO"] == "/metrics"
      return [503, HEADERS, ["Metrics not ready"]] unless ready?

      response = format(
        RESPONSE_TEMPLATE,
        read_bytes_per_second: $disk_read_bytes_per_second,
        write_bytes_per_second: $disk_write_bytes_per_second,
      )

      [200, HEADERS, [response]]
    else
      [404, HEADERS, ["Not Found"]]
    end
  end

  private

  def ready?
    $disk_read_bytes_per_second && $disk_write_bytes_per_second
  end
end

Thread.new do
  loop do
    result = DiskBench.run(blocks: 100)
    $disk_read_bytes_per_second = result[:read][:bytes_per_second]
    $disk_write_bytes_per_second = result[:write][:bytes_per_second]

    read_megabytes = $disk_read_bytes_per_second / 1.megabyte
    write_megabytes = $disk_write_bytes_per_second / 1.megabyte

    puts "Disk Bench Results: Read #{read_megabytes.to_i} MB/s, Write #{write_megabytes.to_i} MB/s"

    sleep 1.minute
  end
end
