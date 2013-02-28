#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/feature_confine_collection'

describe Puppet::Provider::FeatureConfineCollection do
  let (:subject) { Puppet::Provider::FeatureConfineCollection.new("name", "label", "docs") }

  it "should be able to add confines" do
    should respond_to(:confine)
  end

  it "should require name, label and docs at initialization" do
    lambda { Puppet::Provider::FeatureConfineCollection.new }.should raise_error(ArgumentError)
  end

  it "should make its name available" do
    Puppet::Provider::FeatureConfineCollection.new("myname", "mylabel", "mydocs").name.should == "myname"
  end

  it "should make its label available" do
    Puppet::Provider::FeatureConfineCollection.new("myname", "mylabel", "mydocs").label.should == "mylabel"
  end

  it "should make its docs available" do
    Puppet::Provider::FeatureConfineCollection.new("myname", "mylabel", "mydocs").docs.should == "mydocs"
  end

  describe "when creating confine instances" do
    it "should create an instance of the named test with the provided values" do
      test_class = mock 'test_class'
      test_class.expects(:new).with(%w{my values}).returns(stub('confine', :label= => nil))
      Puppet::Provider::Confine.expects(:test).with(:foo).returns test_class

      subject.confine :foo => %w{my values}
    end

    it "should copy its label to the confine instance" do
      confine = mock 'confine'
      test_class = mock 'test_class'
      test_class.expects(:new).returns confine
      Puppet::Provider::Confine.expects(:test).returns test_class

      confine.expects(:label=).with("label")

      subject.confine :foo => %w{my values}
    end

    describe "and the test cannot be found" do
      it "should create a Facter test with the provided values and set the name to the test name" do
        confine = Puppet::Provider::Confine.test(:variable).new(%w{my values})
        confine.expects(:name=).with(:foo)
        confine.class.expects(:new).with(%w{my values}).returns confine
        subject.confine(:foo => %w{my values})
      end
    end
  end

  it "should not be valid if no confines are present" do
    # as the provider should explicitly declare it (has_feature)
    subject.should_not be_valid(nil)
  end

  it "should be valid if all confines pass" do
    c1 = stub 'c1', :valid? => true, :label= => nil
    c2 = stub 'c2', :valid? => true, :label= => nil

    Puppet::Provider::Confine.test(:true).expects(:new).returns(c1)
    Puppet::Provider::Confine.test(:false).expects(:new).returns(c2)

    subject.confine :true => :bar, :false => :bee
    subject.should be_valid(nil)
  end

  it "should not be valid if any confines fail" do
    c1 = stub 'c1', :valid? => true, :label= => nil
    c2 = stub 'c2', :valid? => false, :label= => nil

    Puppet::Provider::Confine.test(:true).expects(:new).returns(c1)
    Puppet::Provider::Confine.test(:false).expects(:new).returns(c2)

    subject.confine :true => :bar, :false => :bee
    subject.should_not be_valid(nil)
  end

  describe "#clone" do
    it "it should deep-clone all of the tests" do
      c1 = stub 'c1', :valid? => true, :label= => nil, :values => [true]
      Puppet::Provider::Confine.test(:true).expects(:new).returns(c1)
      subject.confine :true => :bar

      cloned = subject.clone
      subject.instance_variable_get(:@tests).size.should == cloned.instance_variable_get(:@tests).size
      subject.instance_variable_get(:@tests)[0].values.should == cloned.instance_variable_get(:@tests)[0].values

      subject.instance_variable_get(:@tests).object_id.should_not == cloned.instance_variable_get(:@tests).object_id
      subject.instance_variable_get(:@tests)[0].object_id.should_not == cloned.instance_variable_get(:@tests)[0].object_id
    end
  end
end
