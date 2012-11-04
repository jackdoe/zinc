require File.join(File.dirname(__FILE__),"zinc")
require 'test/unit'
require 'rack/test'
require 'fileutils'
require File.join(ROOT,"zinc_generate")

def __silence
  begin
    if ENV['VERBOSE'].nil?
      ActiveRecord::Base.logger = false
      ActiveRecord::Migration.verbose = false
    end
  rescue 
  end
  ENV['RACK_ENV'] = 'test'
end

__silence

require_application test: true
class TestString < Test::Unit::TestCase
  def test_sanitize
    s = "Aa0_"
    assert_equal ('!@#$%^&*())' + s + '!@{$%^&*()/}#*&////....//.[][]\\').sanitize, s
  end
end
class TestNil < Test::Unit::TestCase
  def test_empty
    s = nil
    assert_nothing_raised do 
      s.empty?
    end
    assert_equal s.empty?,true
  end
end
class TestController < Controller
  def get_return(id)
    @output = id
  end
  def get_cache(arg)
    @cache = true
    @output = 'cached output'
  end
  def get_fcache(arg)
    @cache = 'static_name'
    @output = 'fcached output'
  end
  def get_icache(arg)
    @cache = ''
    @output = 'icached output'
  end
  def get_uncache(*a)
    self.truncate_cache
    @output = 'done'
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
  def cached_file(c,f)
    @cached_files ||= []
    f = File.join(app.settings.public_folder,"cache","test",c,f)
    @cached_files << f unless @cached_files.include?(f)
    f
  end
  def test_it
    get_and_compare('/test/exception/',500)
    get_and_compare('/unexisting_controller/undefined_action/',404)
    get_and_compare('/test/return/5',"5")
    get_and_compare('/test/return/5',"5",{post: true})
    get_and_compare('/test/list/',"hello world")
  end
  def test_caches
    files = 0
    get_and_compare('/test/cache/',"cached output")
    assert File.exist?(cached_file("cache","index.html"))
    files += 1
    get_and_compare('/test/cache/xxxx',"cached output")
    assert File.exist?(cached_file("cache","xxxx.html"))
    files += 1
    get_and_compare('/test/fcache/xxxx',"fcached output")
    assert File.exist?(cached_file("fcache","static_name.html"))
    files += 1
    get_and_compare('/test/icache/xxxx',"icached output")
    assert File.exist?(cached_file("icache","index.html"))
    files += 1
    get_and_compare('/test/uncache/',"done")
    assert @cached_files.count == files
    @cached_files.each do |f|
        assert !File.exist?(f)
    end
  end
end

class ZZZZMustBeLastBecauseDestorysActiveRecordConnectionGeneratorTest < Test::Unit::TestCase

  def setup
    @prefix = File.join(ROOT,"__test__generation_directory_#{$$}")
    PATHS.each { |k,v| PATHS[k] = PATHS[k].gsub(APP,@prefix) }
  end
  def test_conf_model_and_directory_generation
    #ruby zinc.rb generate model person name:string_not_null
    default = "bzbz"
    generate ["generate","model","zzperson","name:string_not_null","belongs_to:zzcategory"]
    generate ["generate","model","zzcategory","name:string_not_null_unique","bzz:string_not_null_default_#{default}","has_many:zzpeople"]
    require_application
    __silence
    ActiveRecord::Migrator.migrate PATHS[:migrate], ENV['VERSION'] ? ENV['VERSION'].to_i : nil
    category = Zzcategory.new
    category.name = "jazz"
    category.save!
    assert_equal category.bzz,default

    assert_raise ActiveRecord::RecordInvalid do #assert uniqueness
      Zzcategory.new(name: "jazz").save!
    end
    assert_raise ActiveRecord::RecordInvalid do #assert presence
      Zzcategory.new.save!
    end

    person = Zzperson.new
    person.name = "Jack Doe"
    person.zzcategory = category
    person.save!
    assert_raise ActiveRecord::RecordInvalid do #assert relation presence
      uncategorized_person = Zzperson.new
      uncategorized_person.name = "Jack Doe"
      uncategorized_person.save!
    end
    assert_equal Zzperson.count,1
    assert_equal Zzperson.find_by_name("Jack Doe").id,person.id
    assert_equal Zzperson.find_by_name("Jack Doe").zzcategory,category
    assert_raise ActiveRecord::RecordInvalid do # assert uniqueness
      Zzperson.new.save!
    end
    assert_equal Zzcategory.first.zzpeople.first,person

  end
  def teardown
    FileUtils.rm_r @prefix if @prefix =~ /__test__generation_directory_\d+$/
    PATHS.each { |k,v| PATHS[k] = PATHS[k].gsub(@prefix,APP) }
  end
end

