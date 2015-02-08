# -*- coding: utf-8 -*-
require 'rubygems'
require 'json'
require 'mongo'
require 'time'
require './libgetdata.rb'
#path of csv
csvpath = './data/csv/'


db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
c_taskqueue	= db.collection('c_taskqueue')
c_reportlist= db.collection('c_reportlst')
sets = c_taskqueue.find('status'=>0).sort([:registryTime,:asc])

sets.each do |queue|
		c_taskqueue.update({'_id'=>queue['_id']},{'$set' => {'status' => -1}})
end

sets = c_taskqueue.find('status'=>-1).sort([:registryTime,:asc])
sets.each do |queue|
	meigara		= queue["meigara"]
	starttime = queue["startTime"].localtime
	endtime		= queue["endTime"].localtime
	date			= Time.local(starttime.year,starttime.month,starttime.day,0,0,0)

	data="time,meigara,bid,offer,company\n"
	
	obj=DataGet.new
	result=obj.dataGet(starttime,endtime,meigara)
	data<<result
	
	if result ==""
		c_taskqueue.update({'_id'=>queue['_id']},{'$set' => {'status' => 1}})
		exit
	end
	csvfile = starttime.strftime("%Y%m%d%H%M")+meigara+".csv"
	File.open(csvpath+csvfile,"w").write(data)
	`R --vanilla --slave --args  #{csvfile.sub(".csv","").sub("#{meigara}","")} #{meigara}  < makeplot.r `

	eachimgfile	= csvfile.sub(".csv","_each.png")
	fullimgfile	= csvfile.sub(".csv","_full.png")
	meanimgfile	= csvfile.sub(".csv","_mean.png")

	c_reportlist.insert(:date=>date,
											:meigara=>meigara,
											:starttime=>starttime,
											:endtime=>endtime,
											:csvfile=>csvfile,
											:eachimgfile=>eachimgfile,
											:fullimgfile=>fullimgfile,
											:meanimgfile=>meanimgfile
										 )

	c_taskqueue.update({'_id'=>queue['_id']},{'$set' => {'status' => 1}})
end
exit



