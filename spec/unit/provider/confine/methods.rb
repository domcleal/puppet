#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/confine/methods'

describe Puppet::Provider::Confine::Methods do
  it "should be named :methods" do
    Puppet::Provider::Confine::Methods.name.should == :methods
  end

  it "should require a value" do
    lambda { Puppet::Provider::Confine::Methods.new }.should raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    Puppet::Provider::Confine::Methods.new("somemethod").values.should be_instance_of(Array)
  end

  describe "when testing values" do
    before do
      @confine = Puppet::Provider::Confine::Methods.new("mytest")
      @confine.label = "eh"
    end

    it "should check the supplied object for a method" do
      obj = mock "Provider"
      obj.expects(:respond_to?).with(:mytest).returns(true)
      @confine.valid? obj
    end

    it "should return true if the method is present" do
      obj = mock "Provider"
      obj.stubs(:mytest).returns(true)
      @confine.pass?("mytest", obj).should be_true
    end

    it "should return false if the value is false" do
      obj = mock "Provider"
      @confine.pass?("mytest", obj).should be_false
    end
  end

  it "should summarize multiple instances by returning a flattened array of all missing methods" do
    confines = []
    confines << Puppet::Provider::Confine::Methods.new(%w{one two})
    confines << Puppet::Provider::Confine::Methods.new(%w{two})
    confines << Puppet::Provider::Confine::Methods.new(%w{three four})

    features = mock 'feature'
    features.stub_everything
    Puppet.stubs(:features).returns features

    Puppet::Provider::Confine::Methods.summarize(confines, Object.new).sort.should == %w{one two three four}.sort
  end
end
