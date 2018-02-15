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
      @webrick.start
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
          sql = "SELECT COUNT(ip) FROM nodes WHERE ip = '" + ip + "'"
          row = RDFS_DB.execute(sql)
          if row[0][0] == 0
            sql = "INSERT INTO nodes (ip) VALUES ('" + ip + "')"
            RDFS_DB.execute(sql)
            response_text = "Node with IP " + ip + " added.\n"
          else
            response_text = "Node with IP " + ip + " was already registered.\n"
          end
        # Remove a node
        when "delete_node"
          sql = "DELETE FROM nodes WHERE ip = '" + ip + "'"
          RDFS_DB.execute(sql)
          response_text = "Node with IP " + ip + " removed.\n"
      end

      return 200, "text/plain", response_text
    end

  end

end
