# encoding: utf-8
require 'sinatra'
require 'haml'
require 'mongo'
require "sinatra/reloader" if development?
require 'open-uri'
require 'yaml'

open("setting.yaml").read
conf = YAML.load(open("setting.yaml").read)

#db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratesnalysismanage').db('ratesnalysismanage')
#c_queue = db.collection('c_queue')

@@errormessage = nil

helpers do
	include Rack::Utils; alias_method :h, :escape_html
end

def active_navigation(item, param)
	"active" if param == item
end


set :sessions, true

get '/favicon.ico' do
end

get '/addtaskqueue/' do
	now=Time.now - 60*2
	@starttime = Time.local(now.year,now.month,now.day,now.hour,now.min,0).strftime("%Y%m%d%H%M")
	now+=60*2
	@endtime = Time.local(now.year,now.month,now.day,now.hour,now.min,0).strftime("%Y%m%d%H%M")
	@pageid = "addtaskqueue"
	haml :addtaskqueue
end



get '/' do
	now=Time.now
	@starttime = Time.local(now.year,now.month,now.day,now.hour,now.min,0).strftime("%Y%m%d%H%M%S")
	@pageid = "home"
	haml :index
end


get '/resultlist/' do
	db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
	collection = db.collection('c_reportlst')
	@sets = collection.find.sort([:starttime,:desc])
	@urlbase = 'http://hirose30.net/ratefeed/data/'
	@pageid = "resultlist"
	haml :resultlist
end


get '/taskqueuemanage/' do
	db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
	collection = db.collection('c_taskqueue')
	@sets = collection.find.sort([:registryTime,:desc])
	@pageid = "taskqueuemanage"
	haml :taskqueuemanage
end

post '/addtaskqueue/confirm' do
	@@confirmparam = params
	if params[:endtime] <= params[:starttime]
		@@errormessage = "終了時間より開始時間が遅くなっています。入力条件を見なおしてください"
		redirect '/addtaskqueue/'
	end
	@pageid = "taskqueuemanage"
	haml :addtaskqueue_confirm
end

post '/addtaskqueue/registry' do
	@regparam= params
	@@confirmparam = nil
	starttime=nil
	if /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/=~@regparam[:starttime]
		starttime = Time.local($1,$2,$3,$4,$5,0)
		p starttime
	end
	endtime=nil
	if /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/=~@regparam[:endtime]
		endtime = Time.local($1,$2,$3,$4,$5,0)
		p endtime
	end
	db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
	collection = db.collection('c_taskqueue')
	now = Time.now
	collection.insert(
		:registryTime=>now,
		:updateTime=>now,
		:meigara=>@regparam[:meigara],
		:startTime => starttime,
		:endTime => endtime,
		:status => 0
	)
	
	@pageid = "taskqueuemanage"
	haml :addtaskqueue_registry
end


get '/regist/:digitcode' do
	digitcode = params[:digitcode]
	#p digitcode
	where_query={:digitcode=>digitcode,:accept=>false}
	result=c_mailaccept.find_one(where_query)
	if result
		c_mailaccept.update(
			{:digitcode=>digitcode},
			{'$set'=>{:accept=>true}},
			:safe=>true)
		email=result['email']
		now = Time.now
		hash = Digest::SHA1.new.update(email+now.to_s)
		c_users.insert(:email=>email,:hash=>hash.to_s,:timestamp=>now)
		Mail.new(:charset => 'ISO-2022-JP') do
			from "2chreschecker@hirose30.net"
			to "#{email}"
			subject "2ch Res Checker 登録完了"
			body "2ch Res Checker 本登録完了
本登録が完了しました。スレッドの登録は下記のURLからお願いします。
#{BASEURL}user/#{hash.to_s}

--------
(C)Takamasa Hirose
"
		end.deliver
	else
		redirect '/'
	end
	haml :regist_accept
end
