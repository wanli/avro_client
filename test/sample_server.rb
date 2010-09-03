require 'socket'
require 'rubygems'
require 'avro'

AVRO_PROTOCOL = Avro::Protocol.parse(File.open("#{File.expand_path(File.dirname(__FILE__))}/sample_protocol.json", 'r').read)

class SampleResponder < Avro::IPC::Responder
  def initialize(name)
    super(AVRO_PROTOCOL)
    @name = name
  end

  def call(message, request)
    raise ArgumentError, "Blank message" if message.name.nil?
    raise ArgumentError, "Blank request" if request.nil?

    send(message.name.to_sym, request) if self.public_methods.include?(message.name)
  rescue ArgumentError => e
    e.inspect
  end

  def make_sample(request)
    sample_name = request['sample_name'] || 'default sample name'
    raise ArgumentError, "Invalid sample count specified" if request['sample_count'] <= 0
    (1..request['sample_count']).map { |sample_id| { 'name' => sample_name, 'id' => sample_id, 'maker' => @name } }
  end
end

class SampleHandler
  def initialize(name, address, port)
    @name = name
    @ip_address = address
    @port = port
  end

  def run(&block)
    server = TCPServer.new(@ip_address, @port)
    sockets = [server]
    while true
      ready = select(sockets)
      readable = ready[0]

      readable.each do |socket|
        if socket == server
          client = server.accept
          sockets << client
        else
          begin
            handle(socket)
            yield
          rescue => e
            sockets.delete(socket)
            socket.close
          end
        end
      end
    end
  end

  def handle(request)
    responder = SampleResponder.new(@name)
    transport = Avro::IPC::SocketTransport.new(request)
    str = transport.read_framed_message
    transport.write_framed_message(responder.respond(str))
  end
end

if __FILE__ == $0
  requests_processed = 0
  SampleHandler.new('Foobar', 'localhost', 11011).run {
    requests_processed += 1
    puts "Requests processed #{requests_processed}"
  }
end
