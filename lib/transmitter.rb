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

        # Transmit
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
          nodes_row.each do |node|
            row.each do |file|
              ip = node[0]
              sha256sum = file[0]
              filename = file[1]
              # Check to see if the file exists using some other filename.
              # If it does, we make a call to add without actually sending the file.
              uri = URI.parse('http://' + ip + ':' + RDFS_PORT.to_s + '/files')
              response = Net::HTTP.post_form(uri,
                'api_call' => 'add_query', 
                'filename' => filename, 
                'sha256sum' => sha256sum)
              if response.body.include?("EXISTS")
                # File exists but with a different filename, so call the add_dup
                # function to avoid using needless bandwidth
                response = Net::HTTP.post_form(uri,
                  'api_call' => 'add_dup', 
                  'filename' => filename, 
                  'sha256sum' => sha256sum)
                if response.body.include?("OK")
                  clear_update_flag(filename, sha256sum)
                end
              else
                # File doesn't exist on node, so let's push it.
                # Read it into a string (this will have to be improved at some point)
                file_handle = File.open(RDFS_PATH + "/" + filename, "rb")
                file_contents = file_handle.read
                file_handle.close
                # Then push it in a POST call
                response = Net::HTTP.post_form(uri,
                  'api_call' => 'add', 
                  'filename' => filename, 
                  'sha256sum' => sha256sum,
                  'content' => file_contents)
                if response.body.include?("OK")
                  clear_update_flag(filename, sha256sum)
                end
              end
            end
          end
        else
          @logger.debug("No files to transmit.")
        end
      else
        @logger.debug("No nodes found.")
      end
    end

    # Clears the updated flag on a file
    def clear_update_flag(filename, sha256sum)
      sql = "UPDATE files SET updated = 0 WHERE name = '" + filename + "' AND sha256 = '" + sha256sum + "'"
      @logger.debug(sql)
      RDFS_DB.execute(sql)
    end

  end

end

