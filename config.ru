require "sinatra"
require "thin"
require "haml"
require "digest/sha1"
require "mongo"
require "sinatra/reloader" if development?
require "open-uri"
require "yaml"
require "logger"


#use Clogger,
#	:format => :Combined,
#	:path => "./log/access.log",
#	:reentrant => true
logger = Logger.new("log/access.log", "daily")
logger.instance_eval { alias :write :'<<' unless respond_to?(:write) }
use Rack::CommonLogger, logger

helpers do
	include Rack::Utils; alias_method :h, :escape_html
end
	



require "./app.rb"

run Sinatra::Application
