require 'rubygems'
require 'socket'
require "test/unit"
require 'pp'

require "#{File.dirname(__FILE__)}/../lib/avro_client.rb"
require "#{File.dirname(__FILE__)}/sample_server.rb"

class TestSampleServer < Test::Unit::TestCase
  def setup
    @forked_pid1 = fork { SampleHandler.new('server1', 'localhost', 11011).run } 
    @forked_pid2 = fork { SampleHandler.new('server2', 'localhost', 11012).run } 
    @protocol = Avro::Protocol.parse(File.open("#{File.expand_path(File.dirname(__FILE__))}/sample_protocol.json", 'r').read)
    @servers = ['localhost:11011', 'localhost:11012'] 
    @avro = AvroClient.new(@servers, {:protocol => @protocol, :timeout => 5, :raise => true, :retries => 3} )
  end

  def teardown
    Process.kill("HUP", @forked_pid1)
    Process.wait
    Process.kill("HUP", @forked_pid2)
    Process.wait
  end

  def test_both_servers_are_used
    server1_requests = 0
    server2_requests = 0
    for i in 1..10 do
      result = @avro.make_sample('sample_name' => 'Foo', 'sample_count' => 5)
      assert_equal 1, result.first['id']
      server1_requests += 1 if result.first['maker'] == 'server1'
      server2_requests += 1 if result.first['maker'] == 'server2'
    end
    assert server1_requests > 0
    assert server2_requests > 0
    assert_equal 10, server1_requests + server2_requests
  end
end
