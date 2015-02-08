# -*- coding: utf-8 -*-
require 'rubygems'
require 'em-websocket'
require 'json'
require 'mongo'
require 'time'

bids = Hash.new
asks = Hash.new
spreads = Array.new

class	Arbitrage
	def initialize(feeds)
		db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
		@collection = db.collection('c_ratefeed')
		@rates = Hash.new
		#@meigaras = @collection.distinct("meigara")
		@feeds = feeds
		@timestate = 0 #0 is realtime / 1 is setting_time
		@meigara = "USDJPY"
		@time = Time.now
		@delay = 0.25
		@speed = 1
	end
	def checkState
		if @input == true && @inputtimestate == 1
			@timestate = @inputtimestate
			@time = @inputtime#Time.parse(@inputtime)
			@rates = Hash.new
		elsif @input == true && @inputmeigara != ""
			@meigara = @inputmeigara
		end
		@inputtime = ""
		@inputmeigara = ""
		@input = false
		@inputtimestate = 0
	end
	def getLatestRate
		@feeds.each do |feedtype|
			where_query = {:meigara=>@meigara,:feedtype=>feedtype}
			
			if Time.now < @time
				@timestate = 0
				@speed = 1
			end
			if @timestate == 0
				@time = Time.now
			end
			where_query.store(:time,{"$lt"=>@time})
			latestrate=@collection.find(where_query).sort({time:-1}).limit(1).to_a.pop
			if latestrate == nil
				return
			end
			if @rates[@meigara] == nil
				@rates[@meigara]={}
			end
			@rates[@meigara].store(feedtype,[latestrate['time'],latestrate['bid'],latestrate['ask']])
		end
	end
	def searchArbitrageState
		maxbid = nil
		minask = nil

		log = ""
		rate=@rates[@meigara]
		return if rate == nil
		log << @time.utc.to_s << "\n"
		rate.each do |line|
			log << line.to_s << "\n"
		end
		rate.keys.each do |feedtype|
			if (@time - rate[feedtype][0]) > 60
				next
			end
			if maxbid == nil || minask == nil
				maxbid = [feedtype,rate[feedtype][1],rate[feedtype][0]]
				minask = [feedtype,rate[feedtype][2],rate[feedtype][0]]
				next
			end
			if maxbid[1].to_f < rate[feedtype][1].to_f
				maxbid = [feedtype,rate[feedtype][1],rate[feedtype][0]]
			end
			if minask[1].to_f > rate[feedtype][2].to_f
				minask = [feedtype,rate[feedtype][2],rate[feedtype][0]]
			end
		end
		arbstatus = []
		if maxbid != nil #&& (maxbid[2]-minask[2]).abs > 60
			diff = (maxbid[1].to_f - minask[1].to_f)*10000.0
			log << "maxbid:	#{maxbid}\n"
			log << "minask:	#{minask}\n"
			log << "diff #{diff}\n"
			arbstatus = [diff,maxbid,minask]
		end
		return arbstatus
	end
	def makeHtml(arbstatus)
		htmldata = ""
		htmldata << "<p>銘柄:#{@meigara}</p>"
		htmldata << "<p>" << @time.localtime.instance_eval { '%s.%03d' % [strftime('%Y/%m/%d %H:%M:%S'), (usec / 1000.0).round] }.to_s << "更新間隔:"<< @delay.to_s << "秒</p>"
		htmldata << '<div id = table ><ul class= header><li class=meigara></li><li class = bid-ask>bid</li><li class = bid-ask>ask</li><li class = spread>spread</li><li class = time>time</li></ul>'
   	rate=@rates[@meigara]
		return htmldata if rate == nil || arbstatus == [] || arbstatus ==nil
		spreadfmt = "%.f"
		spreadfmt = "%.2f "if /USD$/ =~@meigara
		rate.keys.each do |feedtype|
			feedtime=rate[feedtype][0].localtime
			htmldata << "<ul class= sbifxt>
				<li class = 'meigara'>#{feedtype}</li>
				<li class ='bid-ask'>#{rate[feedtype][1]}</li>
				<li class ='bid-ask'>#{rate[feedtype][2]}</li>
				<li class ='spread' >#{sprintf( spreadfmt,(rate[feedtype][2].to_f-rate[feedtype][1].to_f)*10000)}</li>
				<li class = 'time'>#{feedtime.strftime("%H:%M:%S")}</br>(#{sprintf("%#.3f",@time - feedtime)}秒前)</li>
			</ul>
			"
		end
		htmldata << "</div></br>"
		htmldata << 
			"
			<p>arbitrage status</p>
			<div id = arb_table ><ul class= header >
				<li>Min Ask</li><li>ask price </li><li>Max Bid</li><li>bid price</li><li>Diff</li>
			</ul>
			"
		diff = arbstatus[0]
		diffcss="nonarb"
		if diff > 0 
			diffcss = "arb"
		end
		htmldata << "<ul>
				<li class= #{arbstatus[2][0]}> #{arbstatus[2][0]}</li>
				<li class= #{arbstatus[2][0]} > #{arbstatus[2][1]}</li>
				<li class= #{arbstatus[1][0]} > #{arbstatus[1][0]}</li>
				<li class= #{arbstatus[1][0]} > #{arbstatus[1][1]}</li>
				<li class= #{diffcss} > #{sprintf( spreadfmt,diff)}</li>
			</ul>
		"
		htmldata << "</div></br>"

htmldata<< <<'EOS'
<canvas id="hoge"></canvas>
<script>
var chartdata = {
  "config": {
    "title": "Charts",
    "type": "area",
    "roundedUpMaxY": 10,
    //"minY":8125,
    "bg": "#fff",
    "useMarker": "arc",
		"width":500,
		"height":300,
    "colorSet": 
          ["rgba(240,0,200,1)","rgba(0,150,250,0.8)"]
  },
EOS
	bairitsu = 1
	bairitsu = 100 if /USD$/ =~@meigara
	js_feed_data=["会社"]+rate.keys
  js_feed_bid=["bid"]
	rate.keys.each do |feedtype|
		js_feed_bid<<rate[feedtype][1].to_f*bairitsu*10000.0.to_i
	end
  js_feed_ask=["ask"]
	rate.keys.each do |feedtype|
		js_feed_ask<<rate[feedtype][2].to_f*bairitsu*10000.0.to_i
	end
	htmldata << '"data": ['
	htmldata << js_feed_data.to_s << "," << js_feed_ask.to_s << "," << js_feed_bid.to_s
	htmldata.gsub!("-web","")
htmldata<< <<'EOS'
  ]
};
ccchart.init('hoge', chartdata)
</script>
EOS
	return htmldata
	end
	def makeChart
		rates=@rates[@meigara]
		meanrates=[@time.strftime("%H:%M:%S")]
		meanrates.push(((rates["sbifxt-web"][1].to_f+rates["sbifxt-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["sbifxt100-web"][1].to_f+rates["sbifxt100-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["gmoclick-web"][1].to_f+rates["gmoclick-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["cyber-web2"][1].to_f+rates["cyber-web2"][2].to_f)/2*10000).round)
		meanrates.push(((rates["dmm-web"][1].to_f+rates["dmm-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["moneyp-web"][1].to_f+rates["moneyp-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["gaitame-web"][1].to_f+rates["gaitame-web"][2].to_f)/2*10000).round)
		meanrates.push(((rates["hirose-web1"][1].to_f+rates["hirose-web1"][2].to_f)/2*10000).round)
		JSON.generate(meanrates)
	end
	def setNextLoop
		@delay = 0.25/@speed
		@time+= @delay
		sleep 0.25*@speed
	end
	def receiveWsMessage(mes)
		if /^starttime\=(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/ =~ mes
			begin
				@inputtime = Time.local($1, $2, $3, $4, $5, $6) 
				@inputtimestate = 1
				@input=true
			rescue
			end
		elsif /^meigara\=(.+)/ =~ mes
			@inputmeigara = $1
			@input=true
		elsif /^speed\=(.+)/ =~ mes
			@speed = $1.to_f
		end
	end
end

PORT1 = 4443
PORT2 = 4444
EM::run do
  puts "start websocket server - port:#{PORT2}"
  feeds = ["sbifxt-web","sbifxt100-web","moneyp-web","gaitame-web","cyber-web2","gmoclick-web","hirose-web1","dmm-web"]
	arb = Arbitrage.new(feeds)
  @channel = EM::Channel.new
	EM::WebSocket.start(:host => "0.0.0.0", :port => PORT2) do |ws|
    ws.onopen{
      sid = @channel.subscribe{|mes|
        ws.send(mes)
      }
      ws.onmessage{|mes|
        arb.receiveWsMessage(mes)
        @channel.push("<#{sid}> #{mes}")
      }
      ws.onclose{
        puts "<#{sid}> disconnected"
        @channel.unsubscribe(sid)
      }
    }
  end
  EM::defer do
    loop do
      arb.checkState
			arb.getLatestRate
      @arbstatus = arb.searchArbitrageState
			arb.setNextLoop()
    end
  end
 EM::defer do
		sleep 1
    loop do
			@channel.push	arb.makeHtml(@arbstatus)
			sleep 0.25
		end
	end
end
