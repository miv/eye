require File.dirname(__FILE__) + '/../spec_helper'

def chcpu(cfg = {})
  Eye::Checker.create(123, {:type => :cpu, :every => 5.seconds, 
        :times => 1}.merge(cfg))
end

describe "Eye::Checker::Cpu" do

  describe "without below" do
    subject{ chcpu }

    it "get_value" do
      mock(Eye::SystemResources).cpu_usage(123){ 65 }
      subject.get_value.should == 65
    end

    it "without below always true" do
      stub(subject).get_value{ 15 }
      subject.check.should == true

      stub(subject).get_value{ 20 }
      subject.check.should == true
    end
  end

  describe "with below" do
    subject{ chcpu(:below => 30) }

    it "good" do
      stub(subject).get_value{ 20 }
      subject.check.should == true

      stub(subject).get_value{ 25 }
      subject.check.should == true
    end

    it "good" do
      stub(subject).get_value{ 25 }
      subject.check.should == true

      stub(subject).get_value{ 35 }
      subject.check.should == false
    end

  end

end