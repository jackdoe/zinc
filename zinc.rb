#!/usr/bin/env ruby

require 'sinatra/base'
require 'cgi'
ROOT = File.dirname(__FILE__)


APP = File.join(ROOT,"app")
PATHS = {
  app: APP,
  root: ROOT,
  v: File.join(APP,"v"),
  m: File.join(APP,"m"),
  c: File.join(APP,"c"),
  test: File.join(APP,"test"),
  conf: File.join(APP,"conf"),
  db: File.join(APP,"db"),
  migrate: File.join(APP,"db","migrate")
}
class String
  def sanitize
    self.gsub(/[^a-zA-Z0-9]_/,'')
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
    Dir.glob(File.join("{#{[PATHS[:conf],PATHS[:m],PATHS[:c]].join(',')}}","*.rb")) { |f| require f }
  end
end

class Controller
  attr_reader :params,:session,:request,:argument,:action,:zinc
  def initialize(session,params,request,zinc)
    @session,@params,@request,@zinc = session,params,request,zinc
    @output = nil
    @layout = @request.xhr? ? false : nil
    @action = @params[:action].sanitize rescue ''
    @argument = @params[:splat].first rescue nil
  end
  def start
    self.send("#{@request.request_method.sanitize.downcase}_#{@action}".to_sym,@argument)
    return @output if @output
    return @zinc.erb File.join(self.class.to_s.downcase.gsub(/controller$/,''),@action).to_sym, {:locals  => {:c => self}, :layout => @layout}
  end
  def Controller.find(name)
    return Kernel.const_get(name.to_s.sanitize.capitalize.gsub(/$/,'Controller')) 
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
    alias_method :h, :escape_html		
  end
  def process
    klass = Controller.find(@params[:controller])
    error 404 if klass.nil?
    begin
      klass.new(session,params,request,self).start
    rescue Exception => @exception
      error 500
    end
  end
  error 404 do
    "not found"
  end
  error 500 do
    if settings.environment == :development
      "internal server error<br>exception.message: #{@exception.message rescue 'undefined error'}<br><hr><br>#{@exception.backtrace.join('<br>') rescue ''}"
    else
      "internet server error"
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
