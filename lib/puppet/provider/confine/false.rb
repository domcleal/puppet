require 'puppet/provider/confine'

class Puppet::Provider::Confine::False < Puppet::Provider::Confine
  def self.summarize(confines, obj)
    confines.inject(0) { |count, confine| count + confine.summary }
  end

  def pass?(value, obj = nil)
    ! value
  end

  def message(value)
    "true value when expecting false"
  end

  def summary
    result.find_all { |v| v == false }.length
  end
end
