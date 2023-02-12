# frozen_string_literal: true

class RegexpCollector
  ConstantRegexp = Data.define(:mod, :const_name, :regexp) do
    def name = "%s::%s" % [mod, const_name]
  end

  InstanceMethodRegexp = Data.define(:mod, :method_name, :regexp) do
    def name = "%s#%s: %p" % [mod, method_name, regexp]
  end

  SingletonMethodRegexp = Data.define(:mod, :method_name, :regexp) do
    def name = "%s.%s: %p" % [mod, method_name, regexp]
  end

  attr_reader :mod, :exclude, :exclude_map

  def initialize(mod, exclude: [], exclude_map: {})
    @mod = mod
    @exclude = exclude
    @exclude_map = exclude_map
  end

  def to_a = (consts + code).flat_map { collect_regexps _1 }
  def to_h = to_a.group_by(&:name).transform_values(&:first)

  def excluded?(name_or_obj) =
    exclude&.include?(name_or_obj) || exclude_map[mod]&.include?(name_or_obj)

  def consts
    @consts = mod
      .constants(false)
      .reject { excluded? _1 }
      .map    { [_1, mod.const_get(_1)] }
      .select { _2 in Regexp | Module }
      .reject { excluded? _2 }
      .reject { _2 in Module and "%s::%s" % [mod, _1] != _2.name }
  end

  def code
    return [] unless defined?(RubyVM::InstructionSequence)
    [
      *(mod.methods(false) + mod.private_methods(false))
        .map { mod.method _1 },
      *(mod.instance_methods(false) + mod.private_instance_methods(false))
        .map { mod.instance_method _1 },
    ]
      .reject { excluded?(_1) || excluded?(_2) }
  end

  protected attr_writer :mod

  private

  def collect_regexps(obj) = case obj
  in name, Module  => submod then dup.tap do _1.mod = submod end.to_a
  in name, Regexp  => regexp then ConstantRegexp.new mod, name, regexp
  in Method        => method then method_regexps SingletonMethodRegexp, method
  in UnboundMethod => method then method_regexps InstanceMethodRegexp,  method
  end

  def method_regexps(klass, method)
    iseq_regexps(RubyVM::InstructionSequence.of(method))
      .map { klass.new mod, method.name, _1 }
  end

  def iseq_regexps(obj) = case obj
  in RubyVM::InstructionSequence then iseq_regexps obj.to_a
  in Array                       then obj.flat_map { iseq_regexps _1 }.uniq
  in Regexp                      then excluded?(obj) ? [] : obj
  else []
  end

end
