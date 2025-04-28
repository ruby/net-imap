#!/usr/bin/env ruby
require "benchmark/ips"
require "net/imap"

warmup = 1.0
time   = 5.0
size_lhs = 1000
size_rhs = 1000
max_lhs  = 1400
max_rhs  = 1400

SeqSet = Net::IMAP::SequenceSet
L = SeqSet[Array.new(size_lhs) { rand(1..max_lhs) }]
R = SeqSet[Array.new(size_rhs) { rand(1..max_rhs) }]

puts "Sizes:"
puts "L      runs: %6d numbers: %10d" % [L.elements.count, L.count]
puts "R      runs: %6d numbers: %10d" % [R.elements.count, R.count]

not_l = ~L
not_r = ~R
union = L | R
minus = L - R
anded = L & R
xored = L ^ R
puts "~L     runs: %6d numbers: %10d" % [not_l.elements.count, not_l.count]
puts "~R     runs: %6d numbers: %10d" % [not_r.elements.count, not_r.count]
puts "L | R: runs: %6d numbers: %10d" % [union.elements.count, union.count]
puts "L & R: runs: %6d numbers: %10d" % [anded.elements.count, anded.count]
puts "L ^ R: runs: %6d numbers: %10d" % [xored.elements.count, xored.count]
puts "L - R: runs: %6d numbers: %10d" % [minus.elements.count, minus.count]

puts
puts ?=*72
puts "SequenceSet set ops"
Benchmark.ips do |x|
  x.config(warmup:, time:)
  x.report("L | R") do L | R end
  x.report("L & R") do L & R end
  x.report("L ^ R") do L ^ R end
  x.report("L - R") do L - R end
  x.report("   ~R") do    ~R end

  x.report("L.dup")              do L.dup              end
  x.report("L.dup.merge R")      do L.dup.merge R      end
  x.report("L.dup.intersect! R") do L.dup.intersect! R end
  x.report("L.dup.xor! R")       do L.dup.xor! R       end
  x.report("L.dup.subtract R")   do L.dup.subtract R   end
  x.report("L.dup.complement!")  do L.dup.complement!  end

  x.compare!
end

module Net
  class IMAP
    class SequenceSet

      # (L - R) | (R - L)
      def xor_union_of_diffs(rhs) # :nodoc:
        rhs = SequenceSet.new(rhs)
        (self - rhs) | (rhs - self)
      end

      # (L | R) - (L & R)
      def xor_union_minus_intersection(rhs) # :nodoc:
        rhs = SequenceSet.new(rhs)
        (self | rhs) - (self & rhs)
      end

      # (L - R) | (R - L)
      def xor_union_of_diffs!(rhs) # :nodoc:
        modifying!
        copy = dup
        rhs  = SequenceSet.new(rhs)
        subtract(rhs).merge(rhs.subtract(copy))
      end

      # (L | R) - (L & R)
      def xor_union_minus_intersection!(rhs) # :nodoc:
        modifying!
        copy = dup
        rhs  = SequenceSet.new(rhs)
        merge(rhs).subtract(copy.intersect!(rhs))
      end

    end
  end
end

puts ?=*72
puts "SequenceSet XOR implementations"
Benchmark.ips do |x|
  x.config(warmup:, time:)

  x.report("L ^ R")                 do L ^ R end
  x.report("    (L-R) | (R-L)") do L.dup.xor_union_of_diffs  R end
  x.report("mut (L-R) | (R-L)") do L.dup.xor_union_of_diffs! R end

  x.report("    (L|R) - (L&R)") do L.dup.xor_union_minus_intersection  R end
  x.report("mut (L|R) - (L&R)") do L.dup.xor_union_minus_intersection! R end

  x.compare!
end

puts
puts ?=*72
puts "SequenceSet AND implementations"
Benchmark.ips do |x|
  x.config(warmup:, time:)

  x.report("L & R") do L & R end

  x.report("L - (L - R)") do L - (L - R) end
  x.report("L - (L ^ R)") do L - (L ^ R) end
  x.report("L - ~R")      do L - ~R      end
  x.report("L ^ (L - R)") do L ^ (L - R) end

  x.report("dup L - (L - R)") do L.dup.subtract(L.dup.subtract(R)) end
  x.report("dup L - (L ^ R)") do L.dup.subtract(L.dup.subtract(R.dup.subtract(L))) end
  x.report("dup L - ~R")      do L.dup.subtract(R.dup.complement!) end
  x.report("dup L ^ (L - R)") do L.dup.subtract(L.dup.subtract(R).subtract(L)) end

  x.compare!
end
