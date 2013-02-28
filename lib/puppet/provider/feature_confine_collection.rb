require 'puppet/provider/confine'

# Manages a collection of confines for a single provider feature.
#
# For example a feature X that relies on a method Y being defined will result in the
# confine testing for method Y being added to this collection.
#
# @api private
class Puppet::Provider::FeatureConfineCollection
  attr_reader :name, :label, :docs, :tests

  # @param name [String] name of the feature
  # @param label [String] human-readable description of what is being confined (e.g.
  #   both provider and feature name)
  # @param docs [String] human-readable description of what the feature does
  # @api private
  def initialize(name, label, docs)
    @name = name
    @label = label
    @docs = docs
    @tests = []
  end

  # Add new confines to this collection.  Unknown confine types will be added as
  # Puppet::Provider::Confine::Variable implementations with the type/key taken
  # as the variable name.
  #
  # @param hash [Hash<{Symbol => Object}>] confine type and values it will be
  #   available under
  # @return [void]
  # @api private
  def confine(hash)
    hash.each do |test,values|
      if klass = Puppet::Provider::Confine.test(test)
        @tests << klass.new(values)
      else
        confine = Puppet::Provider::Confine.test(:variable).new(values)
        confine.name = test
        @tests << confine
      end
      @tests[-1].label = self.label
    end
  end

  # Check if all confines in the collection are currently valid.
  #
  # @param obj [Object] object being confined
  # @return [Boolean] true if all confines are valid, false otherwise or if
  #   there are none
  # @api private
  def valid?(obj)
    return false if @tests.empty?
    ! @tests.detect { |c| ! c.valid?(obj) }
  end
  alias_method :available?, :valid?

  # Override of Object#initialize_copy to deep-clone the collection when #clone is
  # called.  Ensures that if a provider has its own additional confines above those
  # specified in the type, then the collection isn't changed.
  #
  # @api private
  def initialize_copy(other)
    super
    other.instance_variable_set(:@tests, @tests.map { |t| t.clone })
  end
end
