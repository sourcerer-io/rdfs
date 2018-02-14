module RDFS

  class Server < WEBrick::HTTPServlet::AbstractServlet

    attr_accessor :webrick 

    def initialize()
      @webrick = WEBrick::HTTPServer.new :Port => RDFS_PORT
      @webrick.start
    end

  end

end
