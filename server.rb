# -*- coding: utf-8 -*-
require 'rubygems'
require 'em-websocket'
require 'mechanize'
require 'kconv'
require 'json'
require 'mongo'


DELAY =0.25

PORT = 4443

EM::run do
	@delay = 1
	
	#Crawl基本クラス
	class CrawlRateS
		@db=""
		def initialize(feedtype,url,delay)
			@feedtype = feedtype
			@url = url
			@delay = delay
			db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
			@collection = db.collection('c_ratefeed')
			@rates = Hash.new
			#@pushtimes = Hash.new
			#@times = Array.new
			@time = ""
			@prerates = nil
		end
		
		def setTime(time)
			@time = time
		end
		def setRates(a,b)
			@rates.store(a,b)
		end
		def dataCheck
			cnt=0
			@rates.keys.each do |meigara|
				#p "meigara"
				if @rates[meigara][0].to_f > @rates[meigara][1].to_f
					cnt+=1
				end
			end
			if cnt >= 1
				p @feedtype
			end
			puts "#{@rates["USDJPY"]}	#{@feedtype}"
		end
		def dataStore
			#dataCheck
			#sleep 5
			#return 1
			if @prerates != nil
				@rates.keys.each do |meigara|
					if @rates[meigara][2] != @prerates[meigara][2]
						@collection.insert(:time=>@time,:meigara=>meigara,:bid=>@rates[meigara][0],:ask=>@rates[meigara][1],:feedtype=>@feedtype)
						#if @feedtype == "sbisec-web" && meigara =="USDJPY"
						#	puts "#{@time}	#{@feedtype}	#{meigara}	#{@rates[meigara][1]}  #{@rates[meigara][2]}store"
						#end
					end
				end
			end
			@prerates = Marshal.load(Marshal.dump(@rates))
			sleep @delay
		end
	end

	#SBIFXT
	class CrawlRate_sbifxt < CrawlRateS
		def dataGet
			@agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE}
			setTime(Time.now)
			#@agent.keep_alive = false
			@agent.get(@url).content.lines do |line|
				#if /^(\w{6})\t\D+\t([\d\.]+)\t([\d\.]+)\t.+\s(\d+)$/ =~ line.toutf8
				if /^(\w{6})\t\D+\t[\d\.]+\t[\d\.]+\t([\d\.]+)\t([\d\.]+)\t.+\s(\d+)$/ =~ line.toutf8
					setRates($1,[$2,$3,$4])
				end
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end

	#GMOCLICK
	class CrawlRate_gmoclick < CrawlRateS
		def dataGet
			@agent = Mechanize.new
			setTime(Time.now)
			@agent.get(@url).content.lines do |line|
				if /^([\w\/]{7})\,([\d\.]+)\,([\d\.]+)\,.+\,([\d\:\/\s]+)$/ =~ line.toutf8
					meigara = $1
					bid = $2
					ask = $3
					time = $4
					meigara.sub!("/","")
					setRates(meigara,[bid,ask,time])
				end
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end
	#END

	#Cyber-web1
	class CrawlRate_ca1 < CrawlRateS
		def dataGet
			@agent = Mechanize.new
			setTime(Time.now)
			@cybertmp_json=""
			json = @agent.get(@url).content.gsub("rateUpdate(","").gsub(");","")
			if(json && json.length >= 2)
				data = JSON.parser.new(json)
				@cybertmp_json=json
			else
				data=JSON.parser.new(@cybertmp_json)
			end
			#pushtime = data.parse()['boardXml']["updatedAt"]
			pushtime = @time
			data.parse()['boardXml']['list'].each do |line|
				setRates(line['cd'].sub("/",""),[line['b'],line['a'],pushtime])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end

	#Cyber-web2
	class CrawlRate_ca2 < CrawlRateS
		def dataGet
			@agent = Mechanize.new
			setTime(Time.now)
			@agent.get(@url).content.gsub(/\<.\>/,'').gsub(/([\/A-Z]+)/,'\n\1').gsub('\n',"\n").lines do |line|
				if /([\w\/]{7})\s+\d+\s+([\d\.]+)\s+([\d\.]+)\s/ =~ line.toutf8
					meigara = $1
					bid = $2
					offer = $3
					meigara.sub!("/","")
					setRates(meigara,[bid,offer,bid])
				end
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end

	#DMM-web1
	class CrawlRate_dmm < CrawlRateS
		def dataGet
			@agent = Mechanize.new
			setTime(Time.now)
			@tmp_json=""
			json = @agent.get(@url).content.gsub(/var priceList.+\"priceList\":/,"").gsub(/\}\;if.+$/,"")
			if(json && json.length >= 2)
				data = JSON.parser.new(json)
				@tmp_json=json
			else
				data=JSON.parser.new(@tmp_json)
			end
			pushtime = @time
			data.parse.each do |line|
				setRates(line["currencyPair"].sub!("/",""), [line["bid"]["price"],line["ask"]["price"],line["timestamp"]])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end
	
	#Hirose-web
	class CrawlRate_hirose < CrawlRateS
		def dataGet
			@agent = Mechanize.new
			setTime(Time.now)
			data=@agent.get(@url)
			data.search('/html/body/quotes/quote').each do |line|
				setRates(line.at('ccy').content,[line.at('bid').content,line.at('ask').content,line.at('bid').content])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end

	#GaitameOnline-web
	class CrawlRate_gaitameonline < CrawlRateS
		def dataGet
      @agent = Mechanize.new{|a| a.user_agent_alias='Windows IE 7'}
			if @tmp_jar != nil
				@agent.cookie_jar = @tmp_jar
			end
			setTime(Time.now)
			tmp_json=""
			json = @agent.get(@url)
			@tmp_jar = @agent.cookie_jar
			json = json.content.gsub("rateUpdate(","").gsub(");","")

			if(json && json.length >= 2)
				data = JSON.parser.new(json)
				tmp_json=json
			else
				data=JSON.parser.new(tmp_json)
			end
			pushtime = @time
			data.parse()['quotes'].each do |line|
				setRates(line['currencyPairCode'],[line['bid'],line['ask'],line['bid']])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end
	#MoneyPartners-web
	class CrawlRate_moneypartners < CrawlRateS
		def dataGet
			@agent = Mechanize.new{|a| a.user_agent_alias='Windows IE 7'}
			if @tmp_jar != nil
				@agent.cookie_jar = @tmp_jar
			end
			setTime(Time.now)
			tmp_json=""
			json = @agent.get(@url)
			@tmp_jar = @agent.cookie_jar
			json = json.content.gsub("var priceList = ","").gsub(";;","")

			if(json && json.length >= 2)
				data = JSON.parser.new(json)
				tmp_json=json
			else
				data=JSON.parser.new(tmp_json)
			end
			pushtime = @time
			data.parse()['priceList'].each do |line|
				data=line['priceData']
				meigara=data['currencyPair']
				meigara.sub!("/","")
				setRates(meigara,[data['bid']['price'],data['ask']['price'],data['timestamp']])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end

	#Rakuten-web
	class CrawlRate_rakuten < CrawlRateS
		@@meigaras = [
			"USDJPY",
			"EURJPY",
			"GBPJPY",
			"AUDJPY",
			"NYDJPY",
			"ZARJPY",
			"CADJPY",
			"CHFJPY",
			"HKDJPY",
			"SGDJPY",
			"EURUSD",
			"GBPUSD",
			"AUDUSD",
			"NZDUSD"
		]
		def dataGet
			@agent = Mechanize.new{|a| a.user_agent_alias='Windows IE 7'}
			if @tmp_jar != nil
				@agent.cookie_jar = @tmp_jar
			end
			setTime(Time.now)
			tmp_json=""
			data = @agent.get(@url)
			@tmp_jar = @agent.cookie_jar
			pushtime = @time
			rates=Array.new
			data.content.each_line do |line|
				rates << line.split(/\t/)
			end
			rates.each do |r|
				next if r[0].to_i > @@meigaras.length || r[0].to_i == 0
				meigara = @@meigaras[r[0].to_i-1]

			  setRates(meigara,[r[12],r[13],r[12]])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end


  class CrawlRate_gaitamedotcom < CrawlRateS
		def dataGet
			@agent = Mechanize.new{|a| a.user_agent_alias='Windows IE 7'}
			if @tmp_jar != nil
				@agent.cookie_jar = @tmp_jar
			end
			setTime(Time.now)
			data = @agent.get(@url)
			@tmp_jar = @agent.cookie_jar
			pushtime = @time
			rates=Array.new
			data.content.each_line do |line|
				next if /^$/=~line
				next if /^,$/=~line
				next if /^12/=~line
				rates << line.split(/,/)
			end
			rates.each do |r|
				setRates(r[0],[r[1],r[2],r[1]])
			end
		end

		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end


  #SBISEC
	class CrawlRate_sbisec < CrawlRateS
		def dataGet
			@agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE}                                      
			setTime(Time.now)
			@agent.get(@url).content.split("!").each do |line|
				rate=line.split(",")
				setRates(rate[0],[rate[1],rate[2],rate[1]])
			end
		end
		def run
			begin
				dataGet
				dataStore
			rescue => e
				p e
			end
		end
		def initialize(feedtype,url,delay = DELAY)
			super(feedtype,url,delay)
			EM::defer do
				loop do
					run()
				end
			end
		end
	end



	CrawlRate_sbifxt.new("sbifxt-web","https://trade.sbifxt.co.jp/api_fxt/HttpApi/Rate.aspx?GUID=RATE1355641201633&AMOUNT=1")
	CrawlRate_sbifxt.new("sbifxt100-web","https://trade.sbifxt.co.jp/api_fxt/HttpApi/Rate.aspx?GUID=RATE1355641201633&AMOUNT=1000000")
	CrawlRate_gmoclick.new("gmoclick-web","https://www.click-sec.com/data/fx/rate/rate.csv")
	CrawlRate_gmoclick.new("gmoclickDemo-web","https://fx-demo.click-sec.com/ygmo/rate.csv")
	CrawlRate_ca2.new("cyber-web2","http://rate.gaikaex.net/quote.txt")
	CrawlRate_dmm.new("dmm-web","https://trade.fx.dmm.com/fxcbroadcast/rpc/FxCPullBsController")
	CrawlRate_hirose.new("hirose-web1","http://hirose-fx.co.jp/currencyExchangeFlashDeveloper/fla_connect2/get_quotes.php")
	CrawlRate_gaitameonline.new("gaitame-web","http://www.gaitameonline.com/rateaj/getrate")
	CrawlRate_moneypartners.new("moneyp-web","https://trade.moneypartners.co.jp/fxcbroadcast/rpc/FxCAjaxPullBsController")
	CrawlRate_rakuten.new("rakuten-web","https://www.rakuten-sec.co.jp/web/fx/RateData/RateData.dat")
	CrawlRate_gaitamedotcom.new("gaitamedotcom-web","https://tradefx.gaitame.com/webpublisher/RateServlet?comcodes=USDJPY&comcodes=EURJPY&comcodes=EURUSD&comcodes=AUDJPY&comcodes=GBPJPY&comcodes=NZDJPY&comcodes=CADJPY&comcodes=CHFJPY&comcodes=HKDJPY&comcodes=GBPUSD&comcodes=USDCHF&comcodes=ZARJPY&tickfrom=&key=aqswdefrtgyhujkilo")
	CrawlRate_sbisec.new("sbisec-web","https://fx.sbisec.co.jp/forex/trade/client/util/getRateManualAllMeigaraIds.aspx?kouzaId=12345678")
end
