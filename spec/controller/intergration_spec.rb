require File.dirname(__FILE__) + '/../spec_helper'

describe "Intergration" do
  before :each do
    @c = Eye::Controller.new
    @c.load(fixture("dsl/integration.eye"))
    @processes = @c.all_processes
    @p1 = @processes.detect{|c| c.name == 'sample1'}
    @p2 = @processes.detect{|c| c.name == 'sample2'}
    @p3 = @processes.detect{|c| c.name == 'forking'}
    @samples = @c.all_groups.detect{|c| c.name == 'samples'}
    sleep 10 # to ensure that all processes started

    @processes.size.should == 3
    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @childs = @p3.childs.keys rescue []
  end

  after :each do
    @processes.each do |p|
      p.schedule(:stop) if p.alive?
    end
    sleep 5
    @processes.each do |process|
      force_kill_process(process) if process.alive?
    end

    force_kill_pid(@old_pid1)
    force_kill_pid(@old_pid2)
    force_kill_pid(@old_pid3)
    (@childs || []).each do |pid|
      force_kill_pid(pid)
    end
  end

  it "status string" do
    @c.status_string.split("\n").size.should == 8
    @c.status_string.strip.size.should > 100
  end

  it "restart process group samples" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid
    @c.send_command(:restart, "samples")
    sleep 11 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should_not == @old_pid1
    @p2.pid.should_not == @old_pid2
    @p3.pid.should == @old_pid3
  end

  it "restart process" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid
    @c.send_command(:restart, "sample1")
    sleep 10 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should_not == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should == @old_pid3
  end

  it "restart process forking" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid
    @c.send_command(:restart, "forking")
    sleep 11 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should_not == @old_pid3
  end

  it "restart missing" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid
    @c.send_command(:restart, "blabla").should == []
    sleep 1
    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should == @old_pid3
  end

  describe "chain" do
    it "restart group with chain sync" do
      @samples.config.merge!(:chain => C.restart_sync)

      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid
      @c.send_command(:restart, "samples")
      sleep 15 # while they restarting

      @processes.map{|c| c.state_name}.uniq.should == [:up]
      @p1.pid.should_not == @old_pid1
      @p2.pid.should_not == @old_pid2
      @p3.pid.should == @old_pid3

      r1 = @p1.states_history.detect{|c| c[:state] == :restarting}[:at]
      r2 = @p2.states_history.detect{|c| c[:state] == :restarting}[:at]

      # >8 because, grace start, and grace stop added
      (r2 - r1).should > 8
    end

    it "restart group with chain async" do
      @samples.config.merge!(:chain => C.restart_async)

      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid
      @c.send_command(:restart, "samples")
      sleep 15 # while they restarting

      @processes.map{|c| c.state_name}.uniq.should == [:up]
      @p1.pid.should_not == @old_pid1
      @p2.pid.should_not == @old_pid2
      @p3.pid.should == @old_pid3

      r1 = @p1.states_history.detect{|c| c[:state] == :restarting}[:at]
      r2 = @p2.states_history.detect{|c| c[:state] == :restarting}[:at]

      # restart sended, in 5 seconds to each
      (r2 - r1).should be_within(0.2).of(5)
    end

    it "if processes dead in chain restart, nothing raised" do
      @samples.config.merge!(:chain => C.restart_async)

      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid
      @c.send_command(:restart, "samples")
      sleep 3

      # in the middle of the process, we kill all processes
      @p1.terminate
      @p2.terminate

      sleep 3

      # nothing happens
      @samples.alive?.should == true
    end
  end

  it "stop group" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid
    @c.send_command(:stop, "samples")
    sleep 7 # while they stopping

    @p1.state_name.should == :unmonitored
    @p2.state_name.should == :unmonitored
    @p3.state_name.should == :up

    Eye::System.pid_alive?(@old_pid1).should == false
    Eye::System.pid_alive?(@old_pid2).should == false
    Eye::System.pid_alive?(@old_pid3).should == true
  end

  it "stop process" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid

    @c.send_command(:stop, "sample1")
    sleep 7 # while they stopping

    @p1.state_name.should == :unmonitored
    @p2.state_name.should == :up
    @p3.state_name.should == :up

    Eye::System.pid_alive?(@old_pid1).should == false
    Eye::System.pid_alive?(@old_pid2).should == true
    Eye::System.pid_alive?(@old_pid3).should == true
  end

  it "unmonitor process" do
    @old_pid1 = @p1.pid
    @old_pid2 = @p2.pid
    @old_pid3 = @p3.pid

    @c.send_command(:unmonitor, "sample1").should == ["int:samples:sample1"]
    sleep 7 # while they stopping

    @p1.state_name.should == :unmonitored
    @p2.state_name.should == :up
    @p3.state_name.should == :up

    Eye::System.pid_alive?(@old_pid1).should == true
    Eye::System.pid_alive?(@old_pid2).should == true
    Eye::System.pid_alive?(@old_pid3).should == true
  end

  describe "delete" do
    it "delete group not monitoring anymore" do
      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid

      @c.send_command(:delete, "samples").should == ["int:samples"]
      sleep 7 # while 

      @c.all_processes.should == [@p3]
      @c.all_groups.map(&:name).should == ['__default__']

      Eye::System.pid_alive?(@old_pid1).should == true
      Eye::System.pid_alive?(@old_pid2).should == true
      Eye::System.pid_alive?(@old_pid3).should == true

      Eye::System.send_signal(@old_pid1)
      sleep 0.5
      Eye::System.pid_alive?(@old_pid1).should == false

      # noone up this
      sleep 2
      Eye::System.pid_alive?(@old_pid1).should == false
    end

    it "delete process not monitoring anymore" do
      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid

      @c.send_command(:delete, "sample1")
      sleep 7 # while 

      @c.all_processes.map(&:name).sort.should == %w{forking sample2}
      @c.all_groups.map(&:name).sort.should == %w{__default__ samples}

      Eye::System.pid_alive?(@old_pid1).should == true
      Eye::System.pid_alive?(@old_pid2).should == true
      Eye::System.pid_alive?(@old_pid3).should == true

      Eye::System.send_signal(@old_pid1)
      sleep 0.5
      Eye::System.pid_alive?(@old_pid1).should == false
    end

    it "delete application" do
      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid

      @c.send_command(:delete, "int")
      sleep 7 # while 

      @c.all_processes.should == []
      @c.all_groups.should == []
      @c.applications.should == []

      Eye::System.pid_alive?(@old_pid1).should == true
      Eye::System.pid_alive?(@old_pid2).should == true
      Eye::System.pid_alive?(@old_pid3).should == true

      Eye::System.send_signal(@old_pid1)
      sleep 0.5
      Eye::System.pid_alive?(@old_pid1).should == false

      actors = Celluloid::Actor.all.map(&:class)
      actors.should_not include(Celluloid::Chain)
      actors.should_not include(Eye::Process)
      actors.should_not include(Eye::Group)
      actors.should_not include(Eye::Application)
      actors.should_not include(Eye::Checker::Memory)
    end

    it "delete by mask" do
      @old_pid1 = @p1.pid
      @old_pid2 = @p2.pid
      @old_pid3 = @p3.pid

      @c.send_command(:delete, "sam*").should == ["int:samples"]
      sleep 7 # while 

      @c.all_processes.should == [@p3]
      @c.all_groups.map(&:name).should == ['__default__']

      Eye::System.pid_alive?(@old_pid1).should == true
      Eye::System.pid_alive?(@old_pid2).should == true
      Eye::System.pid_alive?(@old_pid3).should == true

      Eye::System.send_signal(@old_pid1)
      sleep 0.5
      Eye::System.pid_alive?(@old_pid1).should == false

      # noone up this
      sleep 2
      Eye::System.pid_alive?(@old_pid1).should == false
    end
  end


end