require 'sinatra'
require 'haml'
require 'sequel'

configure do
  require 'ostruct'
  S = OpenStruct.new(
    :cookie_key => 'shitter_cookie'
  )

  db = Sequel.connect('sqlite://s.db')
  unless db.table_exists?(:sheets)
    db.create_table :sheets do
      primary_key :id
      Fixnum :user_id 
      String :content
      timestamp :created_at
    end
  end

  unless db.table_exists?(:users)
    db.create_table :users do
      primary_key :id
      String :username
      String :hash
      String :aboutme
      String :location
    end
  end
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'sheet'
require 'user'

helpers do
  def logged_in?
    request.cookies[S.cookie_key] == true
  end

  def sanity(input)
    input.gsub(/</, "&lt;").gsub(/>/, "&gt;")
  end

  def search_sanity(input)
    input.gsub(/<[^<>]*>/, "")
  end
end

get '/' do
  # redirect to login if not already logged in
  # redirect to '/login'
  @sheets = Sheet.reverse_order(:created_at)
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
  @search_term = params[:search_term]
  if @search_term.nil?
    @results = []
  else
    @search_term = search_sanity(@search_term)
    @results = Sheet.filter(:content.like("%#{@search_term}%"))
  end
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
  sheet = Sheet.new :content => sanity(params[:content]), :created_at => Time.now
  sheet.save
  redirect to('/')
end
