#!/usr/bin/env ruby

require 'sinatra/base'
require 'cgi'
ROOT = File.dirname(__FILE__)
PRODUCTION = (ENV["RACK_ENV"] == "production")

APP = File.join(ROOT,"app")
PATHS = {
  app: APP,
  root: ROOT,
  v: File.join(APP,"v"),
  m: File.join(APP,"m"),
  modules: File.join(APP,"modules"),
  c: File.join(APP,"c"),
  test: File.join(APP,"test"),
  conf: File.join(APP,"conf"),
  db: File.join(APP,"db"),
  migrate: File.join(APP,"db","migrate")
}
class String
  def sanitize
    self.gsub(/[^a-zA-Z0-9_]/,'')
  end
  def escape
    CGI::escapeHTML(self)
  end
end

class Array
  def / len
    a = []
    each_with_index do |x,i|
      a << [] if i % len == 0
      a.last << x
    end
    a
  end
end

class NilClass
  def empty?
    true
  end
end

def require_application(o = {})
  # load conf,models and controllers at the end, so we can add more routes
  if o[:test]
    Dir.glob(File.join(PATHS[:test],"*","*.rb")) { |f| require f }
  else
    Dir.glob(File.join("{#{[PATHS[:conf],PATHS[:modules],PATHS[:m],PATHS[:c]].join(',')}}","*.rb")) { |f| require f }
  end
end

class Controller
  attr_reader :params,:session,:request,:argument,:action,:zinc
  def initialize(session,params,request,zinc)
    @session,@params,@request,@zinc = session,params,request,zinc
    @output = nil
    @layout = @request.xhr? ? false : "layout".to_sym
    @action = @params[:action].sanitize rescue ''
    @argument = @params[:splat].first rescue nil
    @cache = nil
    @cache_ext = "html"
  end
  def truncate_cache
    warn "#{self.class}: truncating #{self.cache_folder}"
    Dir[File.join(self.cache_folder,"**","*.{html,png,jpg,raw}")].each { |x| FileUtils.rm x }
  end
  def cache_folder
    File.join(@zinc.settings.public_folder,"cache")
  end
  def start
    self.send("#{@request.request_method.sanitize.downcase}_#{@action}".to_sym,@argument)
    r = @output || @zinc.erb(File.join(self.name,@action).to_sym, {:locals  => {:c => self}, :layout => @layout})
    if @cache
        # expected nginx config
        # location / {
        #      try_files $uri /cache$uri/index.html /cache$uri.html @proxy;
        # }
        begin
          folder = File.join(self.cache_folder,self.name,@action)
          FileUtils.mkdir_p(folder)
          file = @cache.kind_of?(String) ? @cache : @argument
          file = File.join(folder,"#{file.empty? ? 'index' : file.sanitize}.#{@cache_ext.to_s.sanitize}")
          warn "cache file (#{file}) already exists fix your proxy configuration expected: try_files  $uri /cache$uri/index.html /cache$uri.html @proxy;" if File.exists?(file)
          File.open(file,'wb') { |f| f.write(r) }
        rescue Exception => e
          warn "failed to create cache file #{file} - #{e.message}"
        end
    end
    r
  end
  def name
    self.class.to_s.downcase.gsub(/controller$/,'').sanitize
  end
  def Controller.find(name)
    return (Kernel.const_get(name.to_s.sanitize.capitalize.gsub(/$/,'Controller')) rescue nil)
  end
end

class Zinc < Sinatra::Base
  set :root, APP
  set :views, PATHS[:v]
  set :raise_errors, false
  set :show_exceptions, false
  use Rack::MethodOverride
  configure :development, :test do
    set :logging, true
  end
  helpers do
    include Rack::Utils
    def partial(page, variables={})
      variables[:session] = session
      erb page.to_sym, { layout: false }, variables
    end
    def cached_partial(page, ident, variables={})
      return CACHE["#{page}_#{ident}"] ||= partial(page, variables) if PRODUCTION
      partial(page, variables)
    end
    alias_method :h, :escape_html
  end
  def process
    klass = Controller.find(@params[:controller])
    error 404 if klass.nil?
    begin
      raise ArgumentError unless klass.ancestors.include?(Controller)
      klass.new(session,params,request,self).start
    rescue Exception => @exception
      error 500
    end
  end
  error 404 do
    "not found"
  end
  error 500 do
    if @exception
      warn [@exception.message,@exception.backtrace.first(10)].flatten.join("\n")
      warn '.. backtrace truncated to 10 rows..' if @exception.backtrace.count > 10
    end
    if settings.environment == :development
      "internal server error<br>exception.message: #{@exception.message rescue 'undefined error'}<br><hr><br>#{@exception.backtrace.join('<br>') rescue ''}"
    else
      "internal server error"
    end
  end

  get '/:controller/:action/*' do self.process end
  options '/:controller/:action/*' do self.process end
  put '/:controller/:action/*' do self.process end
  delete '/:controller/:action/*' do self.process end
  post '/:controller/:action/*' do self.process end
end


require_application
if ARGV.count > 0
  require File.join(ROOT,"zinc_generate")
  generate
end
