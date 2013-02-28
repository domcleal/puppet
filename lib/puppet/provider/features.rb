require 'puppet/provider/feature_confine_collection'
require 'puppet/util/docs'
require 'puppet/util'

# Provides feature definitions for types and methods for providers
#
# Features defined for a type allows it to have varying capabilities depending on
# the provider in use and the platform it's running on.  For example, a package
# provider on one platform may only be able to install packages, while on another it
# will be able to upgrade packages too.  The upgrade feature would be defined on the
# package type and capability would be expressed as an available feature of the
# provider for the second platform.
#
# This module models provider features and handles checking whether the features
# are present.  It should not be confused with Puppet::Util::Feature.
#
# The expected workflow is that a type defines all features using {#feature} and
# each is identified by a simple string.  It can then specify that the feature is
# required to manage certain properties.  Next, the provider can explicitly state
# that it implements a given feature using the `has_feature` helper (which gets
# included in the provider class by {Puppet::Type}).
#
# Either the type or the provider can specify confines, so the features are only
# deemed available on the provider if those confines are true.  The type will
# often add a confine for certain methods on the provider, while the provider may
# add a confine based on the host itself, such as a fact.
#
# @api public
module Puppet::Provider::Features
  include Puppet::Util::Docs

  # Defines a feature of providers associated with this type, with the given name
  # and text description.
  #
  # Features can have a series of confines associated with them, so that when all
  # confines pass, the feature is deemed available on the provider.  The confines
  # are passed as a hash of the confine type to values or predicate code.
  #
  # * _fact_name_ => value of fact (or array of facts)
  # * `:exists` => the path to an existing file
  # * `:true` => a predicate code block returning true
  # * `:false` => a predicate code block returning false
  # * `:feature` => name of a feature ({Puppet::Util::Feature}) that must be present
  # * `:methods` => name of provider method that must be defined (or array of methods)
  #
  # @example
  #   feature :manages_homedir, "The provider can create and remove home directories"
  #   feature :installable, "The provider can install packages.", :methods => [:install]
  #
  # @param name [String] the name of the provider feature
  # @param docs [String] description of the feature, used in generated docs
  # @param hash [Hash<{Symbol => Object}>] optional hash of confines
  # @return [void]
  # @dsl type
  # @api public
  def feature(name, docs, hash = {})
    @features ||= {}
    name = name.intern
    raise Puppet::DevError, "Feature #{name} is already defined" if @features.include?(name)
    @features[name] = create_collection name, docs
    @features[name].confine(hash) unless hash.empty?
  end

  # Creates a new confine collection for a feature.  Takes the same parameters as the
  # {#feature} method.
  #
  # @return [Puppet::Provider::FeatureConfineCollection] new collection
  # @see #feature
  # @api private
  def create_collection(name, docs)
    Puppet::Provider::FeatureConfineCollection.new name, "#{self.name}.#{name}", docs
  end
  private :create_collection

  # @return [String] Returns a string with documentation covering all features.
  def featuredocs
    str = ""
    @features ||= {}
    return nil if @features.empty?
    names = @features.keys.sort { |a,b| a.to_s <=> b.to_s }
    names.each do |name|
      doc = @features[name].docs.gsub(/\n\s+/, " ")
      str += "- *#{name}*: #{doc}\n"
    end

    if providers.length > 0
      headers = ["Provider", names].flatten
      data = {}
      providers.each do |provname|
        data[provname] = []
        prov = provider(provname)
        names.each do |name|
          if prov.feature?(name)
            data[provname] << "*X*"
          else
            data[provname] << ""
          end
        end
      end
      str += doctable(headers, data)
    end
    str
  end

  # @return [Array<String>] Returns a list of feature names.
  # @api public
  def features
    @features ||= {}
    @features.keys
  end

  # Generates a module that sets up the boolean predicate methods to test for given
  # features.  Designed to be included into a provider class.  Defines the following
  # methods:
  #
  # * `feature?(String)` => returns Boolean for whether the named feature is available
  # * `features` => returns Array<String> for all available features
  # * `satisfies?(Array<String>)` => returns Boolean for whether all named features are
  #   available
  # * `<feature>?` => one method per feature name, returns Boolean for if available
  # * `has_features(Array<String>)` => declare the given feature is available (aliased
  #   as `has_feature` too)
  # * `confine_feature(String, Hash<{Symbol => Object}>]` => declare that the given
  #   feature is available if the given hash of confines passes
  # 
  # This method itself is a private API, however the methods it creates in the
  # resulting module, which are then available in providers constitute part of the
  # public API for the types/providers DSL.
  #
  # @example
  #   confine_feature :manages_passwords, :feature => :libshadow
  #
  # @return [Module] new module with helper methods
  # @dsl type
  # @api private
  def feature_module
    unless defined?(@feature_module)
      @features ||= {}
      @feature_module = ::Module.new
      const_set("FeatureModule", @feature_module)

      # Provider-local clone of the original type-declared features and feature tests
      # since the provider may add new tests to enable certain features
      features = {}
      @features.each { |f,c| features[f] = c.clone }

      # Create a feature? method that can be passed a feature name and
      # determine if the feature is present.
      @feature_module.send(:define_method, :feature?) do |name|
        method = name.to_s + "?"
        return !!(respond_to?(method) and send(method))
      end

      # Create a method that will list all functional features.
      @feature_module.send(:define_method, :features) do
        return false unless defined?(features)
        features.keys.find_all { |n| feature?(n) }.sort { |a,b|
          a.to_s <=> b.to_s
        }
      end

      # Create a method that will determine if a provided list of
      # features are satisfied by the curred provider.
      @feature_module.send(:define_method, :satisfies?) do |*needed|
        ret = true
        needed.flatten.each do |feature|
          unless feature?(feature)
            ret = false
            break
          end
        end
        ret
      end

      # Create a boolean method for each feature so you can test them
      # individually as you might need.
      features.each do |name, feature|
        method = name.to_s + "?"
        @feature_module.send(:define_method, method) do
          (is_a?(Class) ? declared_feature?(name) : self.class.declared_feature?(name)) or feature.available?(self)
        end
      end

      # Allow the provider to declare that it has a given feature.
      @feature_module.send(:define_method, :has_features) do |*names|
        @declared_features ||= []
        names.each do |name|
          @declared_features << name.intern
        end
      end
      # Aaah, grammatical correctness
      @feature_module.send(:alias_method, :has_feature, :has_features)

      # Allow the provider to add confines to already defined features.  These
      # confines are added to the provider's copy of the collection.
      @feature_module.send(:define_method, :confine_feature) do |name, hash|
        feature = features[name.intern]
        raise Puppet::DevError, "Unable to find feature #{name}" unless feature
        feature.confine(hash)
      end
    end
    @feature_module
  end

  # @return [ProviderFeature] Returns a provider feature instance by name.
  # @param name [String] the name of the feature to return
  # @note Should only be used for testing.
  # @api private
  #
  def provider_feature(name)
    return nil unless defined?(@features)

    @features[name.intern]
  end
end

