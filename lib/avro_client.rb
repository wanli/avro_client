require 'rubygems'
require 'avro'
require 'avro_client/abstract_avro_client.rb'

class AvroClient < AbstractAvroClient
  class NoServersAvailable < StandardError; end
  include RetryingAvroClient
  include TimingOutAvroClient

=begin rdoc
Create a new AvroClient instance. Accepts a list of servers with ports, and options. The options should include <tt>:protocol</tt>.

Valid optional parameters are:

<tt>:protocol</tt>:: Which Avro protocol to use.
<tt>:randomize_server_list</tt>:: Whether to connect to the servers randomly, instead of in order. Defaults to <tt>true</tt>.
<tt>:exception_classes</tt>:: Which exceptions to catch and retry when sending a request. Defaults to <tt>[IOError, Errno::EPIPE, Errno::ECONNRESET, Avro::AvroError]</tt>
<tt>:raise</tt>:: Whether to reraise errors if no responsive servers are found. Defaults to <tt>true</tt>.
<tt>:retries</tt>:: How many times to retry a request. Defaults to the number of servers defined.
<tt>:server_retry_period</tt>:: How many seconds to wait before trying to reconnect after marking all servers as down. Defaults to <tt>1</tt>. Set to <tt>nil</tt> to retry endlessly.
<tt>:server_max_requests</tt>:: How many requests to perform before moving on to the next server in the pool, regardless of error status. Defaults to <tt>nil</tt> (no limit).

=end rdoc

  def initialize(servers, options = {})
    super
  end
end
