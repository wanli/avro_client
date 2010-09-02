require 'timeout'

class AbstractAvroClient

  DEFAULTS = {
    :raise => true,
    :defaults => {}
  }.freeze

  attr_reader :requestor, :current_server, :server_list, :options

  def initialize(servers, options = {})
    @options = DEFAULTS.merge(options)
    @server_list = Array(servers)
    @current_server = @server_list.first
  end

  def inspect
    "<#{self.class} @current_server=#{@current_server}>"
  end

  def request(*args)
    handled_proxy('request', *args)
  end

  def method_missing(*args)
   args[0] = args[0].to_s
   request(*args)
  end

  # Force the requestor to connect to the server. Not necessary to be
  # called as the connection will be made on the first RPC method
  # call.
  def connect!
    host, port = @current_server.split(":")
    @socket = TCPSocket.new(host, port)
    @transport = Avro::IPC::SocketTransport.new(@socket)
    @requestor = Avro::IPC::Requestor.new(@options[:protocol], @transport)
  rescue Avro::AvroError, Errno::ECONNREFUSED, Errno::EPIPE, IOError => e
    @transport.close rescue nil
    raise e
  end

  def disconnect!
    @transport.close rescue nil
    @requestor = nil
    @current_server = nil
  end

  private
  def handled_proxy(method_name, *args)
    proxy(method_name, *args)
  rescue Exception => e
    handle_exception(e, method_name, args)
  end

  def proxy(method_name, *args)
    connect! unless @requestor
    send_rpc(method_name, *args)
  end

  def send_rpc(method_name, *args)
    @requestor.send(method_name, *args)
  end

  def disconnect_on_error!
    @transport.close rescue nil
    @requestor = nil
    @current_server = nil
  end

  def handle_exception(e, method_name, args=nil)
    raise e if @options[:raise]
    if args
      @options[:defaults][args[0].to_sym]
    else
      @options[:defaults][method_name.to_sym]
    end
  end

  module RetryingAvroClient
    DISCONNECT_ERRORS = [
                         IOError,
                         Errno::EPIPE,
                         Errno::ECONNRESET
                        ].freeze

    RETRYING_DEFAULTS = {
      :exception_classes => DISCONNECT_ERRORS,
      :randomize_server_list => true,
      :retries => nil,
      :server_retry_period => 1,
      :server_max_requests => nil,
      :retry_overrides => {}
    }.freeze

    def initialize(servers, options = {})
      super
      @options = RETRYING_DEFAULTS.merge(@options) # @options is set by super
      @retries = options[:retries] || @server_list.size
      @request_count = 0
      @max_requests = @options[:server_max_requests]
      @retry_period = @options[:server_retry_period]
      srand
      rebuild_live_server_list!
    end

    def connect!
      @current_server = next_server
      super
    rescue Errno::ECONNREFUSED, Errno::EPIPE, IOError => e
      retry
    end

    def disconnect!
      # Keep live servers in the list if we have a retry period. Otherwise,
      # always eject, because we will always re-add them.
      if @retry_period && @current_server
        @live_server_list.unshift(@current_server)
      end

      super()
      @request_count = 0
    end

    private

    def next_server
      if @retry_period
        rebuild_live_server_list! if Time.now > @last_rebuild + @retry_period
        raise AvroClient::NoServersAvailable, "No live servers in #{@server_list.inspect} since #{@last_rebuild.inspect}." if @live_server_list.empty?
      elsif @live_server_list.empty?
        rebuild_live_server_list!
      end
      @live_server_list.pop
    end

    def rebuild_live_server_list!
      @last_rebuild = Time.now
      if @options[:randomize_server_list]
        @live_server_list = @server_list.sort_by { rand }
      else
        @live_server_list = @server_list.dup
      end
    end

    def handled_proxy(method_name, *args)
      disconnect_on_max! if @max_requests and @request_count >= @max_requests
      super
    end

    def proxy(method_name, *args)
      super
    rescue *@options[:exception_classes] => e
      disconnect!
      tries ||= (@options[:retry_overrides][method_name.to_sym] || @retries)
      tries -= 1
      tries == 0 ? handle_exception(e, method_name, args) : retry
    end

    def send_rpc(method_name, *args)
      @request_count += 1
      super
    end

    def disconnect_on_max!
      # thrift_client simply does:
      #   @live_server_list.push(@current_server)
      # then the client will chose the same server(@current_server) again.
      # this will make the client choose a different server if there is one
      # available.
      @live_server_list.insert(0, @current_server)
      disconnect_on_error!
    end

    def disconnect_on_error!
      super
      @request_count = 0
    end

  end

  module TimingOutAvroClient
    TIMEOUT_DEFAULTS = {
      :timeout => 1,  # in seconds
      :timeout_overrides => {}
    }.freeze

    def initialize(servers, options = {})
      super
      @options = TIMEOUT_DEFAULTS.merge(@options)
    end

    def proxy(method_name, *args)
      request_name = args[0] ? args[0].to_sym : ''
      request_timeout = @options[:timeout_overrides][request_name] || @options[:timeout]
      if request_timeout
        Timeout::timeout(request_timeout) {
          return super
        }
      else
        super
      end
    end
  end
end
