require File.dirname(__FILE__) + '/../spec_helper'

describe "comamnd spec" do
  subject{ c = Eye::Controller.new; c.load(fixture("dsl/load.eye")); c }

  before :each do
    @apps = subject.applications

    @app1 = @apps.first
    @app2 = @apps.last

    @gr1 = @app1.groups[0]
    @gr2 = @app1.groups[1]
    @gr3 = @app1.groups[2]
    @gr4 = @app2.groups[0]

    @p1 = @gr1.processes[0]
    @p2 = @gr1.processes[1]
    @p3 = @gr2.processes[0]
    @p4 = @gr3.processes[0]
    @p5 = @gr3.processes[1]
    @p6 = @gr4.processes[0]
  end

  describe "remove objects" do
    it "remove app" do
      subject.remove_object_from_tree(@app2)
      subject.applications.size.should == 1
      subject.applications.first.should == @app1
    end

    it "remove group" do
      subject.remove_object_from_tree(@gr1)
      @app1.groups.should_not include(@gr1)

      subject.remove_object_from_tree(@gr2)
      @app1.groups.should_not include(@gr2)

      subject.remove_object_from_tree(@gr3)
      @app1.groups.should_not include(@gr3)

      @app1.groups.should == []
    end

    it "remove process" do
      subject.remove_object_from_tree(@p1)
      @gr1.processes.should_not include(@p1)

      subject.remove_object_from_tree(@p2)
      @gr1.processes.should_not include(@p2)

      @gr1.processes.should == []
    end
  end

  describe "send_command" do
    it "nothing" do
      subject.load(fixture("dsl/load.eye")).should include(error: false)
      subject.send_command(:start, "2341234").should == []
    end

    it "unknown" do
      subject.load(fixture("dsl/load.eye")).should include(error: false)
      subject.send_command(:st33art, "2341234").should == []
    end

    [:start, :stop, :restart, :unmonitor].each do |cmd|
      it "should send_command #{cmd}" do
        any_instance_of(Eye::Process) do |p|
          dont_allow(p).send_command(cmd)          
        end

        mock(@p1).send_command(cmd)

        subject.send_command cmd, "p1"
      end
    end

    it "delete obj" do
      any_instance_of(Eye::Process) do |p|
        dont_allow(p).send_command(:delete)
      end

      mock(@p1).send_command(:delete)
      subject.send_command :delete, "p1"

      subject.all_processes.should_not include(@p1)
      subject.all_processes.should include(@p2)
    end
  end

end