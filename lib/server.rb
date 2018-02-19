module RDFS

  class Server < WEBrick::HTTPServlet::AbstractServlet

    attr_accessor :webrick 
    attr_accessor :logger

    def initialize()

      # Setup logging inside the server
      @logger = Logger.new(STDOUT)
      if RDFS_DEBUG
        @logger.level == Logger::DEBUG
      else
        @logger.level == Logger::WARN
      end
 
      @webrick = WEBrick::HTTPServer.new :Port => RDFS_PORT
      @webrick.mount "/nodes", Nodes
      @webrick.mount "/files", Files
      @webrick.start
    end

  end

  class Files < WEBrick::HTTPServlet::AbstractServlet

    attr_accessor :logger

    # Process a POST request
    def do_POST(request, response)
      status, content_type, body = api_handler(request)
      response.status = status
      response['Content-Type'] = content_type
      response.body = body
    end

    private

    def api_handler(request)
      
      # We assume this by default, but can change it as the function progresses
      response_text = "OK"

      # Grab the IP of the requester
      ip = request.remote_ip

      case request.query['api_call']
        when "add"
          filename = request.query['filename']
          final_filename = RDFS_PATH + "/" + filename
          
          # Decode, decompress, then save the file
          # We could use better compression, but for now this will work.
          puts "Wrote file " + final_filename
          File.write(final_filename, Base64.decode64(request.query['content']))
          
          # There's no need to INSERT into the database, the updater will
          # do this for us text time around.
          
        when "add_dup"
          filename = request.query['filename']
          sha256sum = request.query['sha256sum']

          # Grab the original filename
          query = DB.prepare("SELECT name FROM files WHERE sha256 = :sha256")
          query.bind_param('sha256', sha256sum)
          row = query.execute
          if row.count > 0
            old_name = RDFS_PATH + "/" + row[0]
            new_name = RDFS_PATH + "/" + filename
            FileUtils.cp(old_name, new_name)
          else
            # SHA256 not found
            # File deleted after query but before add_dup?
            response_text = "NOT_FOUND"
          end

        when "delete"
          # Delete file was called
          filename = request.query['filename']
          full_filename = RDFS_PATH + "/" + filename
          if File.exists?(full_filename)
            File.unlink(full_filename)
          else
            response_text = "NOT_FOUND"
          end

        when "add_query"
          # Check if duplicate exists
          sha256sum = request.query['sha256sum']
          query = RDFS_DB.prepare("SELECT sha256 FROM files WHERE sha256 = :sha256")
          query.bind_param('sha256', sha256sum)
          row = query.execute
          if row.count > 0
            response_text = "EXISTS"
          else
            response_text = "NOT_FOUND"
          end
      end

      return 200, "text/plain", response_text
    end

  end

  class Nodes < WEBrick::HTTPServlet::AbstractServlet

    attr_accessor :logger

    # Process a POST request
    def do_POST(request, response)
      status, content_type, body = api_handler(request)
      response.status = status
      response['Content-Type'] = content_type
      response.body = body
    end

    private

    def api_handler(request)
      
      # We assume this by default, but can change it as the function progresses
      response_text = "OK"

      # Grab the IP of the requester
      ip = request.remote_ip

      case request.query['api_call']
        # Add a node
        when "add_node"
          query = RDFS_DB.prepare("SELECT ip FROM nodes WHERE ip = :ip")
          query.bind_param('ip', ip)
          row = query.execute
          unless row.count > 0
            query = RDFS_DB.prepare("INSERT INTO nodes (ip) VALUES (:ip)")
            query.bind_param('ip', ip)
            query.execute
            response_text = "Node with IP " + ip + " added.\n"
          else
            response_text = "Node with IP " + ip + " was already registered.\n"
          end
        # Remove a node
        when "delete_node"
          query = RDFS_DB.prepare("DELETE FROM nodes WHERE ip = :ip")
          query.bind_param('ip', ip)
          query.execute
          response_text = "Node with IP " + ip + " removed.\n"
      end

      return 200, "text/plain", response_text
    end

    # Create SHA256 of a file
    def sha256file(file)
      return Digest::SHA256.file(file).hexdigest
    end

  end

end
