#!/usr/bin/env ruby
require "benchmark/ips"
require "net/imap"

warmup = 1.0
time   = 5.0
size_a = 10_000
size_b = 10_000
max_a  = 14_000
max_b  = 14_000

SeqSet = Net::IMAP::SequenceSet
a = SeqSet[Array.new(size_a) { rand(1..max_a) }]
b = SeqSet[Array.new(size_b) { rand(1..max_b) }]

puts ?=*72
puts "SequenceSet XOR implementations"
Benchmark.ips do |x|
  x.config(warmup:, time:)

  # the original was missing the "a.dup", so it crashed or mutated a!
  x.report("a ^ b") do a.dup ^ b end
  x.report("new (a - b) | (b - a)") do
    SeqSet.new(a).subtract(b).merge(SeqSet.new(b).subtract(a))
  end
  x.report("dup (a - b) | (b - a)") do
    a.dup.subtract(b).merge(b.dup.subtract(a))
  end
  x.report("(a.dup | b).subtract(a & b)") do (a.dup | b).subtract(a & b) end
  x.report("dup (a | b) - (a & b)") do a.dup.merge(b).subtract(a & b) end

  x.report("(a - b) | (b - a)") do (a - b) | (b - a) end
  x.report("(a | b) - (a & b)") do (a | b) - (a & b) end

  x.compare!
end
