require 'rubygems'
require 'socket'
require "test/unit"
require 'pp'

require "#{File.dirname(__FILE__)}/../lib/avro_client.rb"
require "#{File.dirname(__FILE__)}/sample_server.rb"

class TestSampleServer < Test::Unit::TestCase
  def setup
    @forked_pid = fork { SampleHandler.new('test_simple', 'localhost', 11011).run } 
    @protocol = Avro::Protocol.parse(File.open("#{File.expand_path(File.dirname(__FILE__))}/sample_protocol.json", 'r').read)
    @servers = ['localhost:11011'] 
    @avro = AvroClient.new(@servers, {:protocol => @protocol, :timeout => 5, :raise => true, :retries => 3} )
  end

  def teardown
    Process.kill("HUP", @forked_pid)
    Process.wait
  end

  def test_basic
    result = @avro.make_sample('sample_name' => 'Foo', 'sample_count' => 5)
    assert_equal 5, result.size
    for sample in result
      assert_equal 'Foo', sample['name']
      assert_equal 'test_simple', sample['maker']
    end 
    assert_equal 1, result.first['id']
  end

  def test_default_sample_name
    result = @avro.make_sample('sample_count' => 3)
    assert_equal 3, result.size
    for sample in result
      assert_equal 'default sample name', sample['name']
      assert_equal 'test_simple', sample['maker']
    end 
    assert_equal 1, result.first['id']
  end 

  def test_invalid_sample_count
    result = @avro.make_sample('sample_name' => 'Foo', 'sample_count' => -5)
    assert_equal "#<ArgumentError: Invalid sample count specified>", result
  end
end
