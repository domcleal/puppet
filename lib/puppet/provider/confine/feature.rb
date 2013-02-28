require 'puppet/provider/confine'

class Puppet::Provider::Confine::Feature < Puppet::Provider::Confine
  def self.summarize(confines, obj)
    confines.collect { |c| c.values }.flatten.uniq.find_all { |value| ! confines[0].pass?(value) }
  end

  # Is the named feature available?
  def pass?(value, obj = nil)
    Puppet.features.send(value.to_s + "?")
  end

  def message(value)
    "feature #{value} is missing"
  end
end

