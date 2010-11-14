#!/usr/bin/env ruby 

require 'rubygems'
require 'optparse'
require 'ostruct'
require 'date'

class App
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
  end

  # Parse options, check arguments, then process the command
  def run
    puts "Running"
    if parsed_options? && arguments_valid? 
      puts "In run"
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      process_arguments            
      process_command
      
      puts "\nFinished at #{DateTime.now}" if @options.verbose
      
    else
      #puts "Usage Message"
    end
      
  end
  
  protected
  
    def parsed_options?
      
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version', "Print Version Information") { output_version ; exit 0 }
      opts.on('-h', '--help',"Show this message") { puts opts ; exit 0 }
      #opts.on('-V', '--verbose') { @options.verbose = true }  
      #opts.on('-q', '--quiet') { @options.quiet = true }
      opts.on('-i', '--init-disk [MOUNTDIR]', String, "Initialize a mounted disk")  { |mount| @options.init = mount}
      opts.on('-e', '--enumerate', "Get a list of all files on all attached disks and store their contents and checksums.") { @options.enumerate = true }
      opts.on('-a', '--dead', "Mark a disk as dead")  { @options.dead = true }
      opts.on('-r', '--recover [FILE]', String, "Recover a file") { |file| @options.recoverfile = file }
      opts.on('-R', '--recover-all', "Recover all files for a specific disk") { @options.recoverall = true }
      opts.on('-p', '--gen-parity', "Generate Parity Bits for all attached disks")  { @options.genparity = true }
      opts.on('-f', '--folder [FOLDER]',String, "Specify a folder to save recovered files to")  { |folder| @options.folder = folder }
      opts.on('-d', '--disk [DISKID]', Integer, "Specify a disk to perform an action on") { |diskid| @options.disk = diskid }
      opts.on('-c', '--check', "Check the consistency of the files on a specific disk") { @options.check = true }
      opts.on('-C', '--recover-inconsistent', "Recover all inconsistent files on a specific disk")  { @options.recoverincon = true }


      #opts = OptionParser.new 
      #opts.on('-v', '--version', "Print")                      { output_version ; exit 0 }
      #opts.on('-h', '--help', "Outputs Help")                        { output_options }
      #opts.on('-V', '--verbose', "Provide Verbose Information")                      { @options.verbose = true }  
      #opts.on('-q', '--quiet')                        { @options.quiet = true }
      #opts.on('-i', '--init-disk [MOUNTDIR]', String, "Initialize a mounted disk")    { |mount| @options.init = mount}
      #opts.on('-e', '--enumerate', "Get a list of all files on all attached disks and store their contents and checksums.")                    { @options.enumerate = true }
      #opts.on('-a', '--dead', "Foo")                         { @options.dead = true }
      #opts.on('-r', '--recover [FILE]', String, "Foo")       { |file| @options.recoverfile = file }
      #opts.on('-R', '--recover-all')                  { @options.recoverall = true }
      #opts.on('-p', '--gen-parity')                   { @options.genparity = true }
      #opts.on('-f', '--folder [FOLDER]',String)       { |folder| @options.folder = folder }
      #opts.on('-d', '--disk [DISKID]', Integer)       { |diskid| @options.disk = diskid }
      #opts.on('-c', '--check')                        { @options.check = true }
      #opts.on('-C', '--recover-inconsistent')         { @options.recoverincon = true }
                 
      opts.parse!(@arguments) rescue return false
      
      process_options
      true      
    end

    # Performs post-parse processing on options
    def process_options
      @options.verbose = false if @options.quiet
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "  #{name} = #{val}"
      end
    end

    def arguments_valid?
      true #if @arguments.length == 1 
    end
    
    # Setup the arguments
    def process_arguments
      
      DataMapper::Logger.new($stdout, :debug) if @options.verbose
      #Init a disk
      LazyDisk.init_or_get(@options.init,@options.enumerate) if @options.init

      #Recover All Files
      if @options.recoverall && @options.disk
        disk = LazyDisk.get(@options.disk)
        if @options.folder
          disk.recover_all_files(@options.folder)
        else
          disk.recover_all_files 
        end
      end
      
      #Recover File
      if @options.recoverfile && @options.disk
        disk = LazyDisk.get(@options.disk)
        puts "Disk:#{disk}"
        files = disk.lazy_file(:file => @options.recoverfile)
        files.each do |file|
          if @options.folder
            file.recover(@options.folder) 
          else
            file.recover 
          end
        end
      end
      
      #Set Dead
      LazyDisk.get(@options.disk).set_dead if @options.dead && @options.disk
      
      #Gen parity
      (LazyDisk.mount_all(@options.enumerate);gen_parity) if @options.genparity
      
      #Check for missing and inconsistent files
      if @options.check && @options.disk
        disk = LazyDisk.get(@options.disk)
        disk.inconsistent
      end
      
      #Check for missing and inconsistent files and recover them
      if @options.recoverincon && @options.disk
        disk = LazyDisk.get(@options.disk)
        disk.inconsistent.each do |recoverfile| 
          files = disk.lazy_file(:file => recoverfile)
          files.each do |file|
            if @options.folder
              file.recover(@options.folder) 
            else
              file.recover 
            end
          end
        end
      end
     
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    def process_command
      #puts "Foo"
      mounts = LazyDisk.mounts
      disks = mounts.map {|m| LazyDisk.mountload(m,@options.enumerate)}
      disks = disks - [nil]
      mounts = mounts - (disks.map { |d| d.mount })
      #disks.each {|d| puts d.mount }
      #puts "End"

      disks = LazyDisk.all

      puts "DiskID\tAvail\tDead\tMount"
      disks.each {|d| puts "#{d.id}\t#{d.connected}\t#{d.dead}\t#{d.mount}"}
      puts "\nUntracked Mounts"
      mounts.each {|m| puts m }

    end

    def process_standard_input
      input = @stdin.read      
      #@stdin.each do |line| 
      #  
      #end
    end
end


require 'dm-core'
require 'dm-types'
require 'yaml'
$config = YAML.load_file("config.yaml")
#DataMapper::Logger.new($stdout, :debug)
require 'pathname'
APP_ROOT = File.dirname(Pathname.new(__FILE__).realpath)
DataMapper.setup(:default, 'sqlite://'+APP_ROOT+$config['database'])
require 'fileutils'
require APP_ROOT+'/lib/xor/xor'
require APP_ROOT+'/lib/lazyraid'
DataMapper.finalize
require  'dm-migrations'
#DataMapper::Model.raise_on_save_failure = true
#DataMapper.auto_migrate!
DataMapper.auto_upgrade! #Tries to upgrade, or create the db if it doesn't exist

puts "App Starting"
# Create and run the application
app = App.new(ARGV, STDIN)
app.run
