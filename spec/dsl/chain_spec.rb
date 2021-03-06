require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Dsl::Chain" do

  it "should understand chain options" do
    conf = <<-E
      Eye.application("bla") do
        chain :grace => 5.seconds

        process("3") do
          pid_file "3"
        end
      end
    E
    
    h = {
      "bla" => {
        :chain=>{
          :start=>{:grace=>5, :action=>:start}, 
          :restart=>{:grace=>5, :action=>:restart}}, 
        :groups=>{
          "__default__"=>{
            :chain=>{
              :start=>{:grace=>5, :action=>:start}, 
              :restart=>{:grace=>5, :action=>:restart}}, 
            :processes=>{
              "3"=>{
                :chain=>{:start=>{:grace=>5, :action=>:start}, 
                :restart=>{:grace=>5, :action=>:restart}}, 
                :pid_file=>"3", 
                :application=>"bla", 
                :group=>"__default__", 
                :name=>"3"}}}}}}

    Eye::Dsl.load(conf).should == h
  end

  it "1 inner group have" do
    conf = <<-E
      Eye.application("bla") do
        group "gr1" do
          chain :grace => 5.seconds
        end

        process("p1"){pid_file('1')}
      end
    E
    
    h = {
      "bla" => {
        :groups=>{
          "gr1"=>{
            :chain=>{:start=>{:grace=>5, :action=>:start}, 
              :restart=>{:grace=>5, :action=>:restart}}, 
              :processes=>{}}, 
          "__default__"=>{
            :processes=>{"p1"=>{:pid_file=>"1", :application=>"bla", :group=>"__default__", :name=>"p1"}}}}}}

    Eye::Dsl.load(conf).should == h
  end

  it "1 group have, 1 not" do
    conf = <<-E
      Eye.application("bla") do
        group "gr1" do
          working_dir "/tmp"
          chain :grace => 5.seconds
        end

        group("gr2"){
          working_dir '/tmp'
        }
      end
    E
    
    h = {
      "bla" => {
        :groups=>{
          "gr1"=>{
            :working_dir=>"/tmp", 
            :chain=>{:start=>{:grace=>5, :action=>:start}, :restart=>{:grace=>5, :action=>:restart}}, 
            :processes=>{}}, 
          "gr2"=>{:working_dir=>"/tmp", :processes=>{}}}}}

    Eye::Dsl.load(conf).should == h
  end

  it "one option" do
    conf = <<-E
      Eye.application("bla") do
        chain :grace => 5.seconds, :action => :start, :type => :async

        process("3") do
          pid_file "3"
        end
      end
    E
    
    h = {"bla" => {
      :chain=>{
        :start=>{:grace=>5, :action=>:start, :type=>:async}}, 
      :groups=>{
        "__default__"=>{
          :chain=>{:start=>{:grace=>5, :action=>:start, :type=>:async}}, 
          :processes=>{"3"=>{:chain=>{:start=>{:grace=>5, :action=>:start, :type=>:async}}, :pid_file=>"3", :application=>"bla", :group=>"__default__", :name=>"3"}}}}}}

    Eye::Dsl.load(conf).should == h
  end

  it "group can rewrite part of options" do
    conf = <<-E
      Eye.application("bla") do
        chain :grace => 5.seconds

        group "gr" do
          chain :grace => 10.seconds, :action => :start, :type => :sync

          process("3") do
            pid_file "3"
          end
        end
      end
    E
    
    h = {"bla" => {
      :chain=>{
        :start=>{:grace=>5, :action=>:start}, 
        :restart=>{:grace=>5, :action=>:restart}}, 
      :groups=>{
        "gr"=>{
          :chain=>{
            :start=>{:grace=>10, :action=>:start, :type=>:sync}, 
            :restart=>{:grace=>5, :action=>:restart}}, 
        :processes=>{"3"=>{:chain=>{:start=>{:grace=>10, :action=>:start, :type=>:sync}, :restart=>{:grace=>5, :action=>:restart}}, :pid_file=>"3", :application=>"bla", :group=>"gr", :name=>"3"}}}}}}

    Eye::Dsl.load(conf).should == h
  end


end