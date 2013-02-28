require 'puppet/provider/confine'

# The class that models the features and handles checking whether the features
# are present based on defined methods.
class Puppet::Provider::Confine::Methods < Puppet::Provider::Confine
  def self.summarize(confines, obj)
    confines.collect { |c| c.values }.flatten.uniq.find_all { |value| ! confines[0].pass?(value, obj) }
  end

  # Requirement is checked by checking if a predicate method has been generated - see {#method_available?}.
  # @param value [String] the method to check for
  # @param obj [Object, Class] the object or class to check if requirements are met
  # @return [Boolean] whether the requirement for this feature is met or not.
  def pass?(value, obj = nil)
    return method_available?(value.intern, obj)
  end

  private

  # Checks whether the given method is available.
  # @param m [String] the method to check for
  # @param obj [Object, Class] the object or class to check if a predicate method are available or not.
  # @return [Boolean] Returns if the specified methods is available or not in the given object.
  def method_available?(m, obj)
    if obj.is_a?(Class)
      return false unless obj.public_method_defined?(m)
    else
      return false unless obj.respond_to?(m)
    end
    true
  end
end
