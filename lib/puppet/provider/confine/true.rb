require 'puppet/provider/confine'

class Puppet::Provider::Confine::True < Puppet::Provider::Confine
  def self.summarize(confines, obj)
    confines.inject(0) { |count, confine| count + confine.summary }
  end

  def pass?(value, obj = nil)
    # Double negate, so we only get true or false.
    ! ! value
  end

  def message(value)
    "false value when expecting true"
  end

  def summary
    result.find_all { |v| v == true }.length
  end
end
