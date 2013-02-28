#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/features'

describe Puppet::Provider::Features do
  before do
    @klass = Class.new
    @klass.send(:extend, Puppet::Provider::Features)
    @klass.send(:include, Puppet::Provider::Features)
  end

  describe "#feature" do
    it "should exist for defining features" do
      @klass.should respond_to(:feature)
    end

    it "should create an empty feature confine collection with no hash" do
      @klass.expects(:name).returns("Provider")
      Puppet::Provider::FeatureConfineCollection.any_instance.expects(:confine).never
      @klass.feature "test", "Test Feature"

      @klass.provider_feature(:test).should be_a(Puppet::Provider::FeatureConfineCollection)
      @klass.provider_feature(:test).name.should == :test
      @klass.provider_feature(:test).label.should == "Provider.test"
      @klass.provider_feature(:test).docs.should == "Test Feature"
    end

    it "should create a feature confine collection and single confine" do
      @klass.expects(:name).returns("Provider")
      Puppet::Provider::FeatureConfineCollection.any_instance.expects(:confine).with(:true => true)
      @klass.feature "test", "Test Feature", :true => true
      @klass.provider_feature(:test).should be_a(Puppet::Provider::FeatureConfineCollection)
    end

    it "should fail if the feature is defined twice" do
      @klass.expects(:name).returns("Provider")
      @klass.feature "test", "Test Feature"
      lambda { @klass.feature "test", "Test Feature" }.should raise_error Puppet::DevError, /already defined/
    end

    it "should accept the name as a symbol" do
      coll = mock "test collection"
      @klass.expects(:create_collection).with(:test, "Test Feature").returns(coll)
      @klass.feature :test, "Test Feature"
      @klass.provider_feature(:test).should == coll
    end

    it "should accept the name as a string" do
      coll = mock "test collection"
      @klass.expects(:create_collection).with(:test, "Test Feature").returns(coll)
      @klass.feature "test", "Test Feature"
      @klass.provider_feature(:test).should == coll
    end
  end

  describe "#features" do
    it "should exist for returning its registered features" do
      @klass.should respond_to(:features)
    end

    it "should return empty array" do
      @klass.features.should == []
    end

    it "should return name of registered feature" do
      @klass.expects(:name).returns("Provider")
      @klass.feature "test", "Test Feature", :true => true
      @klass.features.should == [:test]
    end
  end

  describe "#featuredocs" do
    it "should exist for returning its documentation on features" do
      @klass.should respond_to(:featuredocs)
    end
  end

  describe "#feature_module" do
    before :each do
      @foo = mock 'foo collection'
      @foo.expects(:confine).with(:true => true)
      @foo.stubs(:available?).returns(true)
      # feature_module will clone the collection from the type to the provider
      # return a second double so we can set expectations on either
      @foo2 = mock 'foo collection clone'
      @foo2.stubs(:available?).returns(true)
      @foo.stubs(:clone).returns(@foo2)

      # Unavailable confine
      @bar = mock 'bar collection'
      @bar.expects(:confine).with(:true => true)
      @bar.stubs(:available?).returns(false)
      @bar2 = mock 'bar collection clone'
      @bar2.stubs(:available?).returns(false)
      @bar.stubs(:clone).returns(@bar2)

      @klass.stubs(:create_collection).with(:foo, "Test Feature").returns(@foo)
      @klass.stubs(:create_collection).with(:bar, "Another Feature").returns(@bar)

      @klass.feature "foo", "Test Feature", :true => true
      @klass.feature "bar", "Another Feature", :true => true

      # Create a fake provider object using the module in a similar way to
      # Puppet::Type
      @feature_module = @klass.feature_module
      pklass = Class.new
      pklass.send(:include, @feature_module)
      pklass.send(:extend, @feature_module)
      @provider = pklass.new
    end

    it "should exist for getting a new helper module" do
      @klass.should respond_to(:feature_module)
    end

    it "should always return a singleton module" do
      @klass.feature_module.object_id.should == @feature_module.object_id
    end

    # Test the methods inside the generated module
    context "resulting provider" do
      describe "#feature?" do
        it "should check the <feature>? method for the given <feature>" do
          @provider.expects(:test?).returns(true)
          @provider.feature?("test").should be_true
        end

        it "should accept the feature name as a symbol" do
          @provider.expects(:test?).returns(true)
          @provider.feature?(:test).should be_true
        end

        it "should accept the feature name as a string" do
          @provider.expects(:test?).returns(true)
          @provider.feature?("test").should be_true
        end
      end

      describe "#features" do
        it "should return all features alphabetically" do
          @provider.expects(:feature?).with(:foo).returns(true)
          @provider.expects(:feature?).with(:bar).returns(true)
          @provider.features.should == [:bar, :foo]
        end
      end

      describe "#satisfies?" do
        it "should return true with no features needing satisfying" do
          @provider.satisfies?.should be_true
        end

        it "should return true with 1 of 1 feature needed and available" do
          @provider.expects(:feature?).with("foo").returns(true)
          @provider.satisfies?("foo").should be_true
        end

        it "should return false with one feature not available" do
          @provider.expects(:feature?).with("foo").returns(true)
          @provider.expects(:feature?).with("bar").returns(false)
          @provider.satisfies?("foo", "bar").should be_false
        end

        it "should accept the feature names as symbols" do
          @provider.expects(:foo?).returns(true)
          @provider.satisfies?(:foo).should be_true
        end

        it "should accept the feature names as strings" do
          @provider.expects(:foo?).returns(true)
          @provider.satisfies?("foo").should be_true
        end
      end

      describe "#<feature>?" do
        it "should exist for each feature" do
          [:foo, :bar].each { |f| @provider.should respond_to("#{f}?") }
        end

        it "should return true when the provider's declared_feature? returns true" do
          @provider.class.expects(:declared_feature?).with(:bar).returns(true)
          @provider.bar?.should be_true
        end

        it "should return true when collection#available? is true" do
          @provider.class.expects(:declared_feature?).with(:foo).returns(false)
          @provider.foo?.should be_true
        end

        it "should return false when collection#available? is false" do
          @provider.class.expects(:declared_feature?).with(:bar).returns(false)
          @provider.bar?.should be_false
        end
      end

      describe "#has_features" do
        it "should symbolize the argument and add to @declared_features" do
          @provider.has_features "test"
          @provider.send(:instance_variable_get, :@declared_features).should == [:test]
        end
      end

      describe "#has_feature" do
        it "should symbolize the argument and add to @declared_features" do
          @provider.has_feature "test"
          @provider.send(:instance_variable_get, :@declared_features).should == [:test]
        end
      end

      describe "#confine_feature" do
        it "should raise exception if given feature name isn't known" do
          lambda { @provider.confine_feature :unknown, :true => true }.should raise_error Puppet::DevError, /Unable to find/
        end

        it "should add a new confine to existing feature" do
          @foo2.expects(:confine).with(:false => false)
          @provider.confine_feature "foo", :false => false
        end

        it "should not change confines on the type's collection when called from the provider" do
          @foo.expects(:confine).with(:false => false).never
          @foo2.expects(:confine).with(:false => false)
          @provider.confine_feature "foo", :false => false
        end

        it "should accept the feature name as a symbol" do
          @foo2.expects(:confine).with(:false => false)
          @provider.confine_feature :foo, :false => false
        end

        it "should accept the feature name as a string" do
          @foo2.expects(:confine).with(:false => false)
          @provider.confine_feature "foo", :false => false
        end
      end
    end
  end
end
