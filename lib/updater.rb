module RDFS
    
  class Updater

    attr_accessor :update_frequency
    attr_accessor :main_thread

    # Called upon Updater.new
    def initialize(update_frequency) 
      @update_frequency = update_frequency
      @running = 1
 
      # Setup logging inside the updater
      @logger = Logger.new(STDOUT)
      if RDFS_DEBUG
        @logger.level == Logger::DEBUG
      else
        @logger.level == Logger::WARN
      end
      
      # Create the main thread
      @main_thread = Thread.new kernel
      @logger.debug("Updater thread started.")
    end
       
    # Stop the updater
    def stop
      @running = nil
    end

    private

    attr_writer :running
    attr_accessor :logger

    def kernel
      while @running
        @logger.debug("Updater thread running.")

        update_database

        @logger.debug("Updater thread paused.")
        Thread.pass
        sleep @update_frequency
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

    # Create SHA256 of a string
    # This currently isn't used, but will be used when we split
    # files and transmit blocks instead of whole files.
    def sha256(string)
      return Digest::SHA256.digest string
    end

    # Return a tree of the specified path
    def fetch_tree(path)
      result = Array.new
      Find.find(path) { |e| result << e.sub(RDFS_PATH + "/", "") if e != RDFS_PATH }
      return result
    end

    # Update database with files
    def update_database
      files = fetch_tree(RDFS_PATH)
  
      # Iterate through each entry and check to see if it is in the database
      files.each { |f|

        # Reconstruct full path and get last modified time
        full_filename = RDFS_PATH + "/" + f
        last_modified = File.mtime(full_filename)
        updated = nil

        # If it's not in the database, hash it and add it to the DB
        row = RDFS_DB.execute("SELECT COUNT(*) FROM files WHERE name = '" + f + "'") 
        if row[0][0] == 0
          # It wasn't in the database, so add it
          file_hash = sha256file(full_filename)
          sql = "INSERT INTO files (sha256, name, last_modified, updated) VALUES ('" + file_hash + "', '" + f + "', " + last_modified.to_i.to_s + ", 1)"
          @logger.debug(sql)
          RDFS_DB.execute(sql)
        else
          # It was in the database, so see if it has changed.
          sql = "SELECT * FROM files WHERE name = '" + f + "'"
          row = RDFS_DB.execute(sql)
          if last_modified.to_i > row[0][2]
            # File has changed. Rehash it and updated the database.
            file_hash = sha256file(full_filename)
            sql = "UPDATE files SET sha256 = '" + file_hash + "', last_modified = " + last_modified.to_i.to_s + ", updated = 1 WHERE name = '" + f + "'"
            @logger.debug(sql)
            RDFS_DB.execute(sql)
          end
        end
      }

    end

  end

end

