require 'puppet/provider/confine'

class Puppet::Provider::Confine::Exists < Puppet::Provider::Confine
  def self.summarize(confines, obj)
    confines.inject([]) { |total, confine| total + confine.summary }
  end

  def pass?(value, obj = nil)
    value && (for_binary? ? which(value) : FileTest.exist?(value))
  end

  def message(value)
    "file #{value} does not exist"
  end

  def summary
    result.zip(values).inject([]) { |array, args| val, f = args; array << f unless val; array }
  end
end
