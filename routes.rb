require 'sinatra'
require 'time'
require 'ohm'
require 'gchart'

get '/' do
  haml :index
end

get '/people' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @people = []
  Person.all.each do |person|
    @people << person
  end
  @people.sort_by! {|person| -Message.find(:sent_to_id => person.id).union(:sent_by_id => person.id).count}
  haml :people
end

get '/person/:person' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @messages = []
  Message.find(:sent_by_id => params[:person]).union(:sent_to_id => params[:person]).each do |message|
    @messages << message
  end
  @messages.sort_by! {|message| message.date}
  haml :person
end

get '/monthly' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @segments = person_by(nil, "month")
  @time_period = @segments[1]
  @segments = @segments[0]
  @gchart = Gchart.line(:data => @segments.values, :size => "460x200", :axis_with_labels => 'y')
  haml :month
end

get '/monthly/:person' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @segments = person_by(Person[params[:person]], "month")
  @time_period = @segments[1]
  @segments = @segments[0]
  @gchart = Gchart.line(:data => @segments.values, :size => "460x200", :axis_with_labels => 'y')
  haml :month, :layout => false
end

get '/weekly' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @segments = person_by(nil, "week")
  @time_period = @segments[1]
  @segments = @segments[0]
  @gchart = Gchart.line(:data => @segments.values, :size => "460x200", :axis_with_labels => 'y')
  haml :month
end

get '/weekly/:person' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @segments = person_by(Person[params[:person]], "week")
  @time_period = @segments[1]
  @segments = @segments[0]
  @gchart = Gchart.line(:data => @segments.values, :size => "460x200", :axis_with_labels => 'y')
  haml :month
end

get '/dictionary/init' do
  build_dic
  redirect url("/dictionary/all")
end

get '/dictionary/nuke' do
  Ohm.redis.zremrangebyscore("dic_all", 0, -1)
  redirect url("/")
end

get '/dictionary/all' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @dictionary = Ohm.redis.zrevrange("dic_all", 0, 99, :withscores => true)
  haml :dictionary
end

get '/dictionary/refreshall' do
  Person.all.each {|person| unless person.id == "1" then build_dic(person.id) end}
  redirect("/people")
end

get '/dictionary/:person_id/refresh' do
  build_dic(params[:person_id])
  redirect url("/dictionary/#{params[:person_id]}")
end

get '/dictionary/:person_id' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @dictionary = Ohm.redis.zrevrange("dic_#{params[:person_id]}", 0, -1, :withscores => true)
  haml :dictionary
end

get '/dictionary/:person_id/sips' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  if Ohm.redis.zcard("ll_#{params[:person_id]}") == 0
    list = Ohm.redis.zrevrange("dic_#{params[:person_id]}", 0, -1)
    list.each do |word|
      ll = log_likelihood(word, params[:person_id])
      Ohm.redis.zadd("ll_#{params[:person_id]}", ll, word)
    end
  end
  @dictionary = Ohm.redis.zrevrange("ll_#{params[:person_id]}", 0, -1, :withscores => true)
  haml :dictionary
end

get '/keyword/:keyword' do
  response['Cache-Control'] = "public, max-age=" + (60*60*24).to_s
  @messages = []
  Message.all.each do |message|
    if message.content.downcase.include? params[:keyword].downcase then @messages << message end
  end
  haml :keyword
end
