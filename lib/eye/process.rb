require 'celluloid'
require_relative 'utils/celluloid_chain'

class Eye::Process
  include Celluloid
  
  autoload :Config,           'eye/process/config'
  autoload :Commands,         'eye/process/commands'
  autoload :Data,             'eye/process/data'
  autoload :Watchers,         'eye/process/watchers'
  autoload :Monitor,          'eye/process/monitor'
  autoload :System,           'eye/process/system'
  autoload :Controller,       'eye/process/controller'
  autoload :StatesHistory,    'eye/process/states_history'
  autoload :Child,            'eye/process/child'
  autoload :Trigger,          'eye/process/trigger'
  autoload :Notify,           'eye/process/notify'
  autoload :Scheduler,        'eye/process/scheduler'

  attr_accessor :pid, :watchers, :config, :states_history, 
                :childs, :triggers, :flapping, :name
  
  def initialize(config)
    raise 'pid file should be' unless config[:pid_file]

    @config = prepare_config(config)
    @logger = Eye::Logger.new(full_name)
    
    @watchers = {}
    @childs = {}
    @triggers = []
    @flapping = false
    @name = @config[:name]

    @states_history = Eye::Process::StatesHistory.new(100)
    @states_history << :unmonitored

    debug "start monitoring config: #{@config.inspect}"

    add_triggers

    super() # for statemachine
  end

  # c(), self[]  
  include Eye::Process::Config
  
  # full_name, status_data
  include Eye::Process::Data
  
  # commands:
  # start_process, stop_process, restart_process
  include Eye::Process::Commands

  # start, stop, restart, monitor, unmonit, delete
  include Eye::Process::Controller
  
  # add_watchers, remove_watchers:
  include Eye::Process::Watchers
  
  # check alive, crush methods:
  include Eye::Process::Monitor

  # system methods:
  include Eye::Process::System

  # manage childs methods
  include Eye::Process::Child

  # manage triggers methods
  include Eye::Process::Trigger

  # manage notify methods
  include Eye::Process::Notify

  # logger methods
  include Eye::Logger::Helpers

  # scheduler
  include Eye::Process::Scheduler
end

# include state_machine states
require_relative 'process/states'
