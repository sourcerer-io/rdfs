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
        update_database
        Thread.pass
        sleep @update_frequency
      end
    end

    # Create SHA256 of a file
    def sha256file(file)
      return Digest::SHA256.file(file).hexdigest
    end

    # Return a tree of the specified path
    def fetch_tree(path)
      result = Array.new
      Find.find(path) { |e| result << e.sub(RDFS_PATH + "/", "") if e != RDFS_PATH }
      return result
    end

    # Update database with files
    def update_database
      
      check_for_deleted_files

      # Fetch a list of all files
      files = fetch_tree(RDFS_PATH)
      @logger.debug("updater: There are currently " + files.size.to_s + " entries in " + RDFS_PATH)

      # Iterate through each entry and check to see if it is in the database
      files.each do |f|
        
        # Reconstruct full path and get last modified time
        full_filename = RDFS_PATH + "/" + f
        last_modified = File.mtime(full_filename)
        updated = nil
        
        # If it's not in the database, hash it and add it to the DB
        row = RDFS_DB.execute("SELECT * FROM files WHERE name = '" + f + "'") 
        if row.count == 0
          # It wasn't in the database, so add it
          file_hash = sha256file(full_filename)
          sql = "INSERT INTO files (sha256, name, last_modified, updated, deleted) VALUES ('" + file_hash + "', '" + f + "', " + last_modified.to_i.to_s + ", 1, 0)"
          @logger.debug("updater: " + sql)
          RDFS_DB.execute(sql)
        else
          # It was in the database, so see if it has changed.
          if last_modified.to_i > row[0][2].to_i
            # File has changed. Rehash it and updated the database.
            file_hash = sha256file(full_filename)
            sql = "UPDATE files SET sha256 = '" + file_hash + "', last_modified = " + last_modified.to_i.to_s + ", updated = 1, deleted = 0 WHERE name = '" + f + "'"
            @logger.debug("updater: " + sql)
            RDFS_DB.execute(sql)
          end
        end
      end
    end

    def check_for_deleted_files
      # Check for deleted files
      sql = "SELECT name FROM files WHERE updated = 0 AND deleted = 0"
      @logger.debug("updater: " + sql)
      all_files = RDFS_DB.execute(sql)
      if all_files.count > 0
        all_files.each do |f|
          filename = f[0]
          full_filename = RDFS_PATH + "/" + filename
          unless File.exists?(full_filename)
            # File doesn't exist, so mark it deleted
            sql = "UPDATE files SET deleted = 1 WHERE name = '" + filename + "'"
            @logger.debug("updater: " + sql)
            RDFS_DB.execute(sql)
          end
        end
      end
    end

  end

end
