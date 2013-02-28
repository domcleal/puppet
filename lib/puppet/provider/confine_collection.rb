require 'puppet/provider/confine'

# Manage a collection of provider confines, returning a boolean or helpful information.
#
# @api private
class Puppet::Provider::ConfineCollection
  # Adds a confine to the collection that is suitable only under the given conditions.
  # The hash describes a confine using mapping from symbols to values or predicate code.
  #
  # Hash keys that are known confine types (subclasses under Puppet::Provider::Confine)
  # will get loaded with the given values that will satisfy the confine.  Other keys will
  # be assumed to be referring to Facter variables and will get loaded using the
  # Puppet::Provider::Confine::Variable implementation.
  #
  # If the :for_binary key is given in the hash, then for_binary = true will be set on
  # the confine itself.  Used with the Exists implementation.
  #
  # @param hash [Hash<{Symbol => Object}>] hash of confines
  # @return [void]
  # @api private
  def confine(hash)
    if hash.include?(:for_binary)
      for_binary = true
      hash.delete(:for_binary)
    else
      for_binary = false
    end
    hash.each do |test, values|
      if klass = Puppet::Provider::Confine.test(test)
        @confines << klass.new(values)
        @confines[-1].for_binary = true if for_binary
      else
        confine = Puppet::Provider::Confine.test(:variable).new(values)
        confine.name = test
        @confines << confine
      end
      @confines[-1].label = self.label
    end
  end

  attr_reader :label

  # @param label [String] human-readable label describing the object being confined
  # @api private
  def initialize(label)
    @label = label
    @confines = []
  end

  # Return a hash of the whole confine set and the number of failing confines (WHY?),
  # used for the Provider reference.
  #
  # @todo ??? unsure if the above is true and what the int is
  # @param obj object being confined
  # @return [Hash<{String => Integer}>] confine names and ???
  # @api private
  def summary(obj = nil)
    confines = Hash.new { |hash, key| hash[key] = [] }
    @confines.each { |confine| confines[confine.class] << confine }
    result = {}
    confines.each do |klass, list|
      value = klass.summarize(list, obj)
      next if (value.respond_to?(:length) and value.length == 0) or (value == 0)
      result[klass.name] = value

    end
    result
  end

  # Check if all confines in the collection are currently valid.
  #
  # @param obj [Object] object being confined
  # @return [Boolean] true if all confines are valid or there are none, false otherwise
  # @api private
  def valid?(obj = nil)
    ! @confines.detect { |c| ! c.valid?(obj) }
  end
end
