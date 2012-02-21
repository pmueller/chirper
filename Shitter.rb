require 'sinatra'
require 'haml'
require 'sequel'

configure do
  require 'ostruct'
  S = OpenStruct.new(
    :user_cookie_key => 'shitter_user_cookie',
    :hash_cookie_key => 'shitter_hash_cookie'
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
      boolean :admin, :default => false
      String :username, :unique => true
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
    not request.cookies[S.user_cookie_key].nil?
  end

  def login(user)
    response.set_cookie(S.user_cookie_key, :value => user.cookie)
    response.set_cookie(S.hash_cookie_key, :value => user[:hash])
  end

  def logout
    response.delete_cookie(S.user_cookie_key)
    response.delete_cookie(S.hash_cookie_key)
  end

  def sanity(input)
    input.gsub(/</, "&lt;").gsub(/>/, "&gt;")
  end

  def search_sanity(input)
    input.gsub(/<[^<>]*>/, "")
  end

  def current_user
    logged_in? ? User[:hash => request.cookies[S.hash_cookie_key]] : nil
  end
end

get '/' do
  # redirect to login if not already logged in
  redirect to '/login' unless logged_in?
  @sheets = Sheet.reverse_order(:created_at)
  haml :index
end

get '/login' do
  haml :login
end

post '/login' do
  # log that bitch in
  user = User[:username => params[:username]]
  redirect to('/login') unless user
  if User.hash_val(params[:username], params[:password]) == user[:hash]
    login(user)
    redirect to('/')
  else
    redirect to('/login')
  end
end

get '/logout' do
  logout
  redirect to('/')
end

get '/register' do
  haml :register
end

post '/register' do
  params.each_key do |k|
    params["#{k}"] = sanity(params["#{k}"])
  end

  if not params[:password].nil? and params[:password] == params[:password_confirm]
    hash = User.hash_val(params[:username], params[:password]) 
    user = User.new :username => params[:username], :hash => "#{hash}", :aboutme => params[:aboutme], :location => params[:location]
    if user.save
      login(user)
      redirect to('/')
    else
      redirect to('/register')
    end
  else
    redirect to('/register')
  end
   
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

get '/users/:id/edit' do
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
