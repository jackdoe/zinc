require File.join('.','zinc')
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'
class TestController < Controller
  def get_return(id)
    @output = id
  end
  def post_return(id)
    @output = id
  end
  def get_list(*unused)
    @output = "hello world"
  end
  def get_exception(*unused)
    raise "oops"
  end
end

class Zinc
  get '/very_strange_and_long_route' do
    "custom"
  end
end

class RouteTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Zinc
  end
  def get_and_compare(uri,expected,o = {})
    if o[:post]
      post uri
    else
      get uri
    end
    if expected.class == Fixnum
      assert_equal last_response.status,expected
    else
      assert_equal last_response.body, expected
    end
  end
  def test_it
    get_and_compare('/',404)
    get_and_compare('/test/exception/',500)
    get_and_compare('/test/return/5',"5")
    get_and_compare('/test/return/5',"5",{post: true})
    get_and_compare('/test/list/',"hello world")
    get_and_compare('/very_strange_and_long_route',"custom")
  end
end

# load application's tests
Dir.glob(File.join(APP_TESTS,"*","*.rb")) { |f| require f }
