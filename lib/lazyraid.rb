$:.unshift File.dirname(__FILE__)



  #$default_block_size = 1024*1024*5

  class LazyDisk
    include DataMapper::Resource
    
    property :id,         Serial
    property :mount,      String
    #attr_accessor :mount
    #property :freespace,  Integer, :min => 0, :max => 2**64-1
    #property :totalspace, Integer, :min => 0, :max => 2**64-1
    #property :tracked,    Boolean, :default => false
    #property :metadata,   FilePath
    property :lastseen,   DateTime
    property :created,    DateTime
    property :dead,       Boolean, :default => false
    
    has n, :lazy_file
    #has n, :lazy_parity
    
    def initialize(mount = "",enum = false)
      self.mount = mount
      self.created = Time.now
      self.lastseen = Time.now
      self.save
      unless new_metadata
        self.destroy
      else
        enumerate if enum
        self.save
      end
    end
    
    def connected
      return false if self.dead
      dirname = self.mount+"/.lazyraid"
      filename = dirname+"/metadata"
      begin
        if File.exists? filename
          fh = File.open(filename,'rb')
          id = fh.read().to_i
          fh.close
          return id == self.id
        end
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
      end
      return false
    end

    def freespace
      if @free.nil? || (Time.now - @freetime) > $config['cache_disk_space']
        begin
          @free = `df -Pk #{self.mount}`.split("\n")[1].split()[3].to_i * 1024
          @freetime = Time.now
        rescue
          $stderr.print "Mount doesn't seem to be connected. ", $!, "\n"
          return 0
        end
      end
      @free
    end
    
    def totalspace
      if @total.nil? || (Time.now - @totaltime) > $config['cache_disk_space']
        begin
          @total = `df -Pk #{self.mount}`.split("\n")[1].split()[1].to_i * 1024
          @totaltime = Time.now
        rescue
          $stderr.print "Mount doesn't seem to be connected. ", $!, "\n"
          return 0
        end
      end
      @total
    end
    
    def self.init_or_get(mount,enum = false)
      dirname = mount+"/.lazyraid"
      filename = dirname+"/metadata"
      begin
        if File.exists? filename
          fh = File.open(filename,'rb')
          id = fh.read().to_i
          fh.close
          begin
            disk = LazyDisk.get(id)
            disk.mount = mount
            disk.lastseen = Time.now
            disk.enumerate if enum
            disk.save
            return disk
          rescue
            $stderr.print "Mount exists but already has an unrecognized lazyraid configuration on it.", $!, "\n"
            return false
          end
        elsif File.exists? mount
          return LazyDisk.new(mount,enum)
        end
      rescue
        $stderr.print "Failed to open #{filename} or #{mount} for reading. ", $!, "\n"
        return false
      end
    end
    def new_metadata
      dirname = self.mount+"/.lazyraid"
      filename = dirname+"/metadata"
      begin
        unless File.exists? dirname
          Dir.mkdir dirname
        end
        fh = File.open(self.mount+"/.lazyraid/metadata",'wb')
        fh.write(self.id)
        fh.close
      rescue
        $stderr.print "Failed to open #{filename} for writing. ", $!, "\n"
        return false
      end
      return true
    end
    
    def inconsistent
      #filehash = Hash.new
      #filehash["inconsistent"] = Array.new
      #filehash["inaccessible"] = Array.new
      #filehash["nottracked"] = Array.new
      
      inconsistent = Array.new
      
      self.lazy_file.all.each do |file| 
        unless File.file?(self.mount+file.file) && file.consistent?
          $stderr.print "File #{self.mount}#{file.file} is inaccessible or inconsistent'", "\n"
          inconsistent.push(file.file)
        end
      end
      
      return inconsistent
      
      #Dir.glob(self.mount+"/**/*").each do |entry|
      #  entry[self.mount] = ""
      #  puts "Entry:"+entry
      #  begin
      #    if File.file?(self.mount+entry) and not entry =~ /^#{self.mount}\/.lazyraid\//
      #      #check if in database
      #      puts "File:"+entry
      #      files = self.lazy_file.all(:file => entry)
      #      if files.count > 0
      #        files.each do |file|
      #          if !file.readable?
      #            filehash["inaccessible"].push(file)
      #          elsif !file.consistent?
      #            filehash["inconsistent"].push(file)
      #          end
      #        end
      #      else
      #        #File doesn't exist
      #        #filehash["nottracked"].push(entry)
      #      end
      #    end
      #  rescue
      #    $stderr.print "Failed to open #{self.mount} for reading. ", $!, "\n"
      #    return false
      #  end
      #end
      #return filehash
    end
    
    def enumerate
      Dir.glob(self.mount+"/**/*").each do |entry|
        entry[self.mount] = ""
        puts "Entry:"+entry
        begin
          if File.file?(self.mount+entry) and File.size(self.mount+entry) >= $config['block_size'] and not entry =~ /^#{self.mount}\/.lazyraid\//
            #check if in database
            puts "File:"+entry
            unless self.lazy_file.all(:file => entry).count > 0
              puts "Create LazyFile:"+entry
              begin
                newfile = LazyFile.new(entry,self.mount)
                self.lazy_file.push(newfile)
              rescue StandardError
                $stderr.print "Error while creating file. Rollingback.", $!, "\n"
              end
            end
          end
        rescue
          $stderr.print "Failed to open #{self.mount} for reading. ", $!, "\n"
          return false
        end
      end
      return self.lazy_file
    end
    
    #Get list of current mount points on system
    def self.mounts
      mounts = `mount | grep "^\/"`.split("\n").map { |line| line.split(" ")[2]}
    end
    
    #Check if exists in DB and init the drive
    def self.mountload(mount,enum = false)
      dirname = mount+"/.lazyraid"
      filename = dirname+"/metadata"
      #begin
        if File.exists? filename
          fh = File.open(filename,'rb')
          id = fh.read().to_i
          fh.close
          disk = LazyDisk.get(id)
          disk.mount = mount
          disk.lastseen = Time.now
          disk.enumerate if enum
          disk.save
          return disk
        end
      #rescue
      #  $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
      #end
      return nil
    end
    
    def self.mount_all(enum)
      LazyDisk.mounts.each {|m| LazyDisk.mountload(m,enum) }
    end
    
    def set_dead
      self.dead = true
      #self.lazy_parity.each do |lp|
      #  lp.lazy_block.each do |b|
      #    b.lazy_parity = nil
      #    b.save
      #  end
      #  lp.destroy
      #end
      self.save
    end
    
    def recover_all_files(folder = ".")
      self.lazy_file.each do |lf|
        lf.recover(folder)
      end
    end
  end

  class LazyFile
    include DataMapper::Resource
    
    property :id,         Serial
    property :file,       String
    property :digest,     String,  :length => 32
    property :lastseen,   DateTime
    property :created,    DateTime
    
    belongs_to :lazy_disk
    has n, :lazy_block

    def initialize(file = "",mount)
      #self.file = File.new(file)
      self.file = file
      self.created = Time.now
      self.lastseen = Time.now
      if compute_digest(mount) && create_blocks(mount)
        $stdout.print "File Created.\n"
      else
        $stderr.print "Digest or Blocks failed", "\n"
        raise StandardError
      end
    end
    
    def compute_digest(mount)
      filename = mount+self.file
      begin
        fh = File.open(filename,'rb')
        self.digest = Digest::MD5.hexdigest(fh.read)
        fh.close
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return false
      end
      return true
    end
    
    def create_blocks(mount)
      size = $config['block_size']
      filename = mount+self.file
      begin
        fh = File.open(filename,'rb')
        #fh = self.file.open('rb')
        while !fh.eof? && bytes = fh.read(size)
          self.lazy_block.push(LazyBlock.new(bytes,fh.pos-bytes.size))
        end
        fh.close
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return false
      end
      return true
    end
    
    def consistent?
      mount = self.lazy_disk.mount
      filename = mount+self.file
      begin
        fh = File.open(filename,'rb')
        return self.digest == Digest::MD5.hexdigest(fh.read)
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return false
      end
      return true
    end
    
    def self.consistent?(digest,filename)
      begin
        fh = File.open(filename,'rb')
        return digest == Digest::MD5.hexdigest(fh.read)
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return false
      end
      return true
    end
    
    def exists?
      filename = self.fullpath
      return File.exists?(filename)
    end
    
    def readable?
      filename = self.fullpath
      return File.exists?(filename) && File.readable?(filename)
    end
    
    def writeable?
      filename = self.fullpath
      return File.exists?(filename) && File.readable?(filename)
    end
    
    def fullpath
      self.lazy_disk.mount + self.file
    end
    
    def recover(folder = self.lazy_disk.mount)
      fileportions = self.lazy_block(:order => [ :offset.asc ])
      filename = folder + self.file
      puts "Attempting recovery of filename."
      begin
        #Create dir structure
        FileUtils.mkdir_p File.dirname(filename)
        puts "Created Dir Structure."
        fileportions.each do |portion|
          puts "Recovering Portion #{portion.offset}"
          parity = portion.lazy_parity
          puts "Parity: #{parity.id}"
          blocks = parity.lazy_block(:order => [ :id.asc ])
          puts "Blocks: #{blocks.size}"
          erased = []
          data = []
          parity = []
          blocks.each_with_index do |block,i|
            #puts "Foo"
            if !block.consistent?
              erased.push(i)
              puts "Erased: #{i.to_s}"
            end
            if block.parity
              parity.push([block.lazy_file.fullpath,block.length])
              #puts "Parity: #{block.id.to_s}"
              puts "Parity: #{block.lazy_file.fullpath.to_s},#{block.length}"
            else
              data.push([block.lazy_file.fullpath,block.length,block.offset])
              #puts "Data: #{block.id.to_s}"
              puts "Data: #{block.lazy_file.fullpath},#{block.length},#{block.offset}"
            end
          end
          
          puts "Cmd: "+data.to_s+","+parity.to_s+","+erased.to_s
          encoder = Parity::Class.new
          
          #Generate Parity Data
          puts "Running Decode Command"
          encoder.decode(data,parity,erased)
          puts "Decode Done"
          
          if !portion.consistent?
            puts "Decode Failed. Portion Not Consistent."
            exit
          else 
            puts "Consistent."
          end
          #exit
        end
      #begin
      #  #Create dir structure
      #  FileUtils.mkdir_p File.dirname(filename)
      #  #Create File
      #  #fh = File.open(filename, 'wb')
      #  blocks.each do |block|
      #    parity = block.lazy_parity
      #    components = parity.lazy_block - [block]
      #    #bytes = parity.data
      #    #components.each do |b|
      #    #  bytes ^= b.data
      #    #end
      #    #fh.write(bytes)
      #    
      #    
      #    xor = XOR::Class.new
  
      #    xor_cmd = []
      #    components.each do |comp|
      #      xor_cmd.push([comp.lazy_file.fullpath, block.length, comp.offset])
      #    end
      #    #length = components.map{|block| block.length }.max
      #    #length = block.length
      #    xor_cmd.push([parity.fullpath,block.length,0 ])
      #    #begin_time = Time.now
      #    puts "Cmd:"+xor_cmd.to_s+","+filename+","+block.length.to_s
      #    xor.xor_multi(xor_cmd,filename,block.length)
      #    
      #    
      #  end
      #  #fh.close
      rescue
        $stderr.print "Failed to open #{filename} for writing. ", $!, "\n"
        return false
      end
      if folder == self.lazy_disk.mount && consistent?
        return true
      elsif LazyFile.consistent?(self.digest,filename)
        return true
      else
        $stderr.print "Something went wrong with the recovery. Recovered file #{filename} is not consistent! ", "\n"
        return false
      end
    end
    
  end

  class LazyBlock
    include DataMapper::Resource
    
    property :id,         Serial
    property :offset,     Integer, :min => 0, :max => 2**64-1
    property :digest,     String,  :length => 32
    property :length,     Integer, :min => 0, :max => 2**64-1
    property :parity,     Boolean, :default => false
    #property :index,      Integer, :required => false
    
    belongs_to :lazy_file
    belongs_to :lazy_parity, :required => false
    
    def initialize(bytes, offset = 0)
      self.length = bytes.size
      self.offset = offset
      self.digest = Digest::MD5.hexdigest(bytes)
    end
    
    def data
      filename = self.lazy_file.lazy_disk.mount+self.lazy_file.file
      begin
        fh = File.open(filename,'rb')
        fh.seek(self.offset, IO::SEEK_SET)
        return fh.read(self.length)
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return nil
      end
    end
    
    def consistent?
      data = self.data
      return false if data.nil?
      return self.digest == Digest::MD5.hexdigest(data)
    end
    
  end

  class LazyParity
    include DataMapper::Resource
    
    property :id,         Serial
    #property :file,       String
    #property :method,     String    #xor,libr8tion
    #property :digest,     String, :length => 32
    
    has n, :lazy_block
    #belongs_to :lazy_disk
    
    def initialize(blocks,targetdisks,encoder)
      #Init Parity Calc
      #start = Time.now
      #memory = `ps -o rss= -p #{Process.pid}`.to_i
      #encoder = Parity::Class.new
      #puts "Parity Class Init: "+(Time.now-start).to_s+"s"
      #puts " Class Init Memory Delta: "+(`ps -o rss= -p #{Process.pid}`.to_i - memory).to_s
      
      #push parity_cmds for blocks
      #start = Time.now
      #memory = `ps -o rss= -p #{Process.pid}`.to_i
      data_cmd = []
      max_length = 0
      blocks.each do |block|
        data_cmd.push([block.lazy_file.fullpath, block.length, block.offset])
        max_length = max_length < block.length ? block.length : max_length
        self.lazy_block.push(block)
      end
      target_cmd = []
      par_files = []
      targetdisks.each do |target|
        file = "/.lazyraid/"+Digest::MD5.hexdigest(Time.now.to_s + rand.to_s)+".block"
        filename = target.mount+file
        target_cmd.push([filename,max_length])
        par_files.push({ "disk" => target, "file" => file })
      end
      #puts "Command Building and write: "+(Time.now-start).to_s+"s"
      #puts "Cmd Memory Delta: "+(`ps -o rss= -p #{Process.pid}`.to_i - memory).to_s
      
      #Generate Parity Data
      start = Time.now
      #memory = `ps -o rss= -p #{Process.pid}`.to_i
      encoder.encode(data_cmd,target_cmd)
      puts "Parity Calc and write: "+(Time.now-start).to_s+"s"
      #puts "Encode Memory Delta: "+(`ps -o rss= -p #{Process.pid}`.to_i - memory).to_s
      
      
      #start = Time.now
      #memory = `ps -o rss= -p #{Process.pid}`.to_i
      par_files.each do |file|
        #insertion order may matter here. Should we add a check?
        #puts "Creating Parity File:#{file["file"]} on #{file["disk"].mount}"
        new_file = LazyFile.new(file["file"],file["disk"].mount)
        #puts "Finished Creating File. #{new_file.digest} : #{new_file.lazy_block.count}"
        #puts "Adding to disk"
        file["disk"].lazy_file.push(new_file)
        #puts "Adding Blocks"
        self.lazy_block.push(new_file.lazy_block.first)
        #puts "Got the blocks pushed"
        self.lazy_block.last.parity = true
        #puts "Set to parity"
      end
      #puts "Parfile creation: "+(Time.now-start).to_s+"s"
      #puts "Parfile Memory Delta: "+(`ps -o rss= -p #{Process.pid}`.to_i - memory).to_s
    end
    
    #def initialize(blocks,targetdisk)
      #bytes = ""
      #blocks.each do |block|
      #  bytes ^= block.data
      #  self.lazy_block.push(block)
      #end
      #xor = XOR::Class.new

      
      
      #xor_cmd = []
      #blocks.each do |block|
      #  xor_cmd.push([block.lazy_file.fullpath, block.length, block.offset])
      #  self.lazy_block.push(block)
      #end
      
      #length = blocks.map{|block| block.length }.max
      
      #self.file = "/.lazyraid/"+Digest::MD5.hexdigest(Time.now.to_s + rand.to_s)+".block"
      #self.lazy_disk = targetdisk
      #filename = targetdisk.mount + self.file
      
      #begin_time = Time.now
      #xor.xor_multi(xor_cmd,filename,length)
      #end_time = Time.now
      #puts "Elapsed:#{(end_time - begin_time)} seconds"
      
      
      #file = "/.lazyraid/"+digest+".block"
      
      #self.digest = Digest::MD5.hexdigest(self.data)
      #self.method = "XOR"

      #self.file = file
      #begin
      #  fh = File.open(filename,'wb')
      #  fh.write(bytes)
      #  fh.close
      #rescue
      #  $stderr.print "Failed to open #{filename} for writing. ", $!, "\n"
      #  raise
      #end
    #end
    
    def consistent?
      mount = self.lazy_disk.mount
      filename = mount+self.file
      begin
        fh = File.open(filename,'rb')
        return self.digest == Digest::MD5.hexdigest(fh.read)
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return false
      end
    end
    
    def data
      filename = self.lazy_disk.mount+self.file
      begin
        fh = File.open(filename,'rb')
        return fh.read
      rescue
        $stderr.print "Failed to open #{filename} for reading. ", $!, "\n"
        return nil
      end
    end
    
    def fullpath
      self.lazy_disk.mount + self.file
    end
    
  end

  def gen_parity
    #Get all disks
    disks = LazyDisk.all().sort{|a,b| a.freespace <=> b.freespace}
    #Remove disks which aren't connected
    disks.delete_if { |disk| !disk.connected }
    encoder = Parity::Class.new
    #Count the number of connected disk blocks that do not already have parity calculated
    while disks.inject(0) { |sum,disk| sum+=disk.lazy_file.lazy_block.all(:lazy_parity => :null).count } > 0 do
      #Iterate over all disks until n-1 blocks have been found or you run out of disks
      start = Time.now
      blocks = []
      disks.each do |disk|
        block = disk.lazy_file.lazy_block.first(:lazy_parity => nil)
        unless block.nil?
          blocks.push(block)
        end
        #Once we've reached a state where we have N-2 blocks or N-1 blocks depending on redundancy we move on
        if blocks.size == (disks.size-$config['redundancy'])
          break
        end
      end
      
      #set parity file to disk with most free space that isn't already part of a block
      pardisks = (disks - (blocks.map {|b| b.lazy_file.lazy_disk}))
      pardisks.delete_if { |disk| disk.freespace < $config['block_size'] }
      if pardisks.size == 0
        $stderr.print "Not enough free disk space to store parity blocks.", "\n"
        break
      end
      #Get the last N disks of the pardisks array. where n is the redundancy number
      targetdisks = []
      while targetdisks.size < $config['redundancy'] && pardisks.size > 0 do
        targetdisks.push(pardisks.pop)
      end
      puts "Block Selection: "+(Time.now-start).to_s+"s"
      
      
      
      begin
        substart = Time.now
        #memory = `ps -o rss= -p #{Process.pid}`.to_i
        parity = LazyParity.new(blocks,targetdisks,encoder)
        puts "Parity Creation: "+(Time.now-substart).to_s+"s"
        #puts "Total Encoding Memory Delta: "+(`ps -o rss= -p #{Process.pid}`.to_i - memory).to_s
        
        substart = Time.now
        parity.save
        puts "Parity Save: "+(Time.now-substart).to_s+"s"
        
        #substart = Time.now
        disks.sort!{|a,b| a.freespace <=> b.freespace}
        #puts "Disk Sort by freespace: "+(Time.now-substart).to_s+"s"
      rescue
        $stderr.print "Failed to create parity block.", $!, "\n"
        $stderr.print "Exiting, please correct the disk errors and regenerate parity.\n"
        break
      end
      puts "Block Elapsed Time: "+(Time.now-start).to_s+"s"
      #puts "TotalMemory:"+`ps -o rss= -p #{Process.pid}`.to_s
    end
  end

  def startup_load
    disks = LazyDisk.mounts.map {|m| LazyDisk.mountload(m) }
    disks = disks - [nil]
  end

  class String
    def ^ (second)
      s = ""
      s.force_encoding("ASCII-8BIT")
      [self.size,second.size].max.times do |i|
        s << ((self[i] || 0).ord ^ (second[i] || 0).ord)
      end
      return s
    end
  end



