# frozen_string_literal: true

$LOAD_PATH.unshift "./lib"
require "net/imap"
require "objspace"

def seqset(n, min: 1, max: (n * 1.25).to_i)
  inputs = Array.new(n) { rand(min..max) }
  Net::IMAP::SequenceSet[inputs]
end

def obj_tree(obj, seen: Set.new)
  seen << obj
  children = ObjectSpace.reachable_objects_from(obj)
    .reject { _1 in Module or seen.include?(_1) }
    .flat_map { obj_tree(_1, seen:) }
  [obj, *children]
end

def memsize(obj) = obj_tree(obj).sum { ObjectSpace.memsize_of _1 }

def avg(ary) = ary.sum / ary.count.to_f

def print_avg(n, count: 10, **)
  print "Average memsize of SequenceSet with %6d inputs: " % [n]
  sizes = Array.new(count) {
    print "."
    memsize seqset(n, **)
  }
  puts "%9.1f" % [avg(sizes)]
end

# pp obj_tree(seqset(200, min: 1_000_000, max: 1_000_999)).to_h { [_1, memsize(_1)] }
print_avg   1
print_avg  10
print_avg 100

print_avg   1_000
print_avg  10_000
print_avg 100_000
