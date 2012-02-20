require 'sinatra'
require 'haml'

get '/' do
  # redirect to login if not already logged in
  redirect to '/login'
  haml :index
end

get '/login' do
  haml :login
end

post '/login' do
  # log that bitch in
end

get '/register' do
  haml :register
end

post 'register' do
  #registerrrr the userrrrr
end

get '/search' do
  haml :search
end

post '/users' do
  # make a user
end

get '/users/:id' do
  # get the user's info... only for that user
end

put '/users/:id' do
  # edit user info
end

post '/sheets' do
  # someone made a sheet
end
