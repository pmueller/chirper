require 'sinatra'
require 'haml'

get '/' do
  haml :index
end

get '/login' do
  haml :login
end

get '/register' do
  haml :register
end

get '/search' do
  haml :search
end
