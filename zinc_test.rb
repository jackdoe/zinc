require File.join(File.dirname(__FILE__),"zinc")
require 'test/unit'
require 'rack/test'
require 'FileUtils'
require File.join(ROOT,"zinc_generate")
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

require_application test: true

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

class GeneratorTest < Test::Unit::TestCase

  def setup
    @prefix = File.join(ROOT,"__test__generation_directory_#{$$}")
    PATHS.each { |k,v| PATHS[k] = PATHS[k].gsub(APP,@prefix) }

  end
  def test_conf_model_and_directory_generation
    #ruby zinc.rb generate model person name:string_not_null
    default = "bzbz"
    generate ["generate","model","person","name:string_not_null","belongs_to:category"]
    generate ["generate","model","category","name:string_not_null_unique","bzz:string_not_null_default_#{default}","has_many:people"]
    require_application
    ActiveRecord::Migrator.migrate PATHS[:migrate], ENV['VERSION'] ? ENV['VERSION'].to_i : nil
    category = Category.new
    category.name = "jazz"
    category.save!
    assert_equal category.bzz,default

    assert_raise ActiveRecord::RecordInvalid do #assert uniqueness
      Category.new(name: "jazz").save!
    end
    assert_raise ActiveRecord::RecordInvalid do #assert presence
      Category.new.save!
    end

    person = Person.new
    person.name = "Jack Doe"
    person.category = category
    person.save!
    assert_raise ActiveRecord::RecordInvalid do #assert relation presence
      uncategorized_person = Person.new
      uncategorized_person.name = "Jack Doe"
      uncategorized_person.save!
    end
    assert_equal Person.count,1
    assert_equal Person.find_by_name("Jack Doe").id,person.id
    assert_equal Person.find_by_name("Jack Doe").category,category
    assert_raise ActiveRecord::RecordInvalid do # assert uniqueness
      Person.new.save!
    end
    assert_equal Category.first.people.first,person

  end
  def teardown
    FileUtils.rm_r @prefix if @prefix =~ /__test__generation_directory_\d+$/
    PATHS.each { |k,v| PATHS[k] = PATHS[k].gsub(@prefix,APP) }
  end
end
