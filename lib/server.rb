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
          tmp_filename = RDFS_PATH + filename + ".rdfstmp"
          final_filename = RDFS_PATH + filename
          
          # Decode, decompress, then save the file
          # We could use better compression, but for now this will work.
          File.write(tmp_filename, Zlib::Inflate.inflate(Base64.decode64(request.query['contents'])))
          
          # Compare SHA256 - if it doesn't match, delete
          if sha256file(tmp_filename) != sha256sum
            File.unlink(tmp_filename)
          else
            File.rename(tmp_filename, final_filename)
          end
          
          # There's no need to INSERT into the database, the updater will
          # do this for us text time around.
          
        when "add_dup"
          # TODO: Add file with matching SHA256 sig

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

    # Create SHA256 of a file
    def sha256file(file)
      return Digest::SHA256.file(file).hexdigest
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
