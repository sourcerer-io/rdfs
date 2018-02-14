module RDFS
    
  class Transmitter

    attr_accessor :main_thread

    # Called upon Transmitter.new
    def initialize(transmit_frequency) 
      @transmit_frequency = transmit_frequency
      @running = 1
 
      # Setup logging inside the updater
      @logger = Logger.new(STDOUT)
      if RDFS_DEBUG
        @logger.level == Logger::DEBUG
      else
        @logger.level == Logger::WARN
      end
      
      # Create the thread
      @main_thread = Thread.new kernel
      @logger.debug("Transmitter thread started.")
    end
       
    # Stop the transmitter
    def stop
      @running = nil
    end

    private

    attr_writer :running
    attr_accessor :logger

    def kernel
      while @running
        @logger.debug("Transmitter thread running.")

        # TODO: Transmit
        transmit

        @logger.debug("Transmitter thread paused.")
        Thread.pass
        sleep @transmit_frequency
      end
    end

    # Reads a binary file and returns its contents in a string
    def read_file(file)
      file = File.open(file, "rb")
      return file.read
    end

    # Create SHA256 of a file
    def sha256file(file)
      return Digest::SHA256.file(file).hexdigest
    end

    # Transmit
    def transmit
      # First, check to see if there are any active nodes. If not, there's no
      # point in wasting DB time in checking for updated files.
      sql = "SELECT * FROM nodes"
      nodes_row = RDFS_DB.execute(sql)
      if nodes_row.count > 0
        sql = "SELECT * FROM files WHERE updated = 1"
        @logger.debug(sql)
        row = RDFS_DB.execute(sql)
        if row.count > 0
          # TODO: Transmit file(s)
        else
          @logger.debug("No files to transmit.")
        end
      else
        @logger.debug("No nodes found.")
      end
    end

  end

end

