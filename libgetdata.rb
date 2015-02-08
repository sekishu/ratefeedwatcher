# -*- coding: utf-8 -*-
require 'json'
require 'mongo'
require 'time'

#DataGet基本クラス
class DataGet
	@db=""
	def initialize
		@db = Mongo::Connection.from_uri('mongodb://localhost:27017/ratedb').db('ratedb')
		@col = @db.collection('c_ratefeed')
	end
	def dataGet(gt=Time.now,lt=Time.now,meigara)
		where_query = {:meigara => meigara}
		#where_query = {}
		if lt != nil
			where_query.store(:time,{"$gt"=>gt,"$lt"=>lt})
		end
		sets=@col.find(where_query)
		output=""
		sets.each do |line|
			time = line["time"].instance_eval { '%s.%03d' % [strftime('%Y-%m-%d %H:%M:%S'), (usec / 1000.0).round] }
			output << "#{time},#{line["meigara"]},#{line["bid"]},#{line["ask"]},#{line["feedtype"]}\n"
		end
		return output
	end
end

