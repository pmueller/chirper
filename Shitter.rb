require 'sinatra'
require 'haml'
require 'sequel'
require 'rack-flash'

enable :sessions
use Rack::Flash, :sweep => true

error do
  'Bummer dude... there was an error'
end

not_found do
  'Bummer dude... 404'
end

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
      String :attachment
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
    not request.cookies[S.hash_cookie_key].nil?
  end

  def login(user)
    #response.set_cookie(S.user_cookie_key, :value => user.cookie)
    response.set_cookie(S.hash_cookie_key, {:value => user[:hash], :path => '/'})
  end

  def logout
    #response.delete_cookie(S.user_cookie_key)
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

  def must_be_logged_in
    if not logged_in?
      flash[:notice] = "You must be logged in to do this"
      redirect to('/login')
    end
  end

  def protect(id)
    if not id.to_i == current_user[:id]
      flash[:notice] = "You are not authorized to view this"
      redirect to('/')
    end
  end
end

get '/' do
  must_be_logged_in
  @sheets = Sheet.reverse_order(:created_at)
  haml :index
end

get '/login' do
  redirect to('/') unless not logged_in?
  haml :login
end

post '/login' do
  redirect to('/') unless not logged_in?
  # log that bitch in
  user = User[:username => params[:username]]
  if not user
    flash[:notice] = "Login failed"
    redirect to('/login')
  end
  if User.hash_val(params[:username], params[:password]) == user[:hash]
    login(user)
    flash[:notice] = "You've logged in as #{user[:username]}"
    redirect to('/')
  else
    flash[:notice] = "Login failed"
    redirect to('/login')
  end
end

get '/logout' do
  must_be_logged_in
  logout
  flash[:notice] = "You have been logged out"
  redirect to('/')
end

get '/register' do
  haml :register
end

post '/register' do
  params.each_key do |k|
    params["#{k}"] = sanity(params["#{k}"])
  end

  if not params[:password].empty? and params[:password] == params[:password_confirm] and not params[:username].empty?
    hash = User.hash_val(params[:username], params[:password]) 
    user = User.new :username => params[:username], :hash => "#{hash}", :aboutme => params[:aboutme], :location => params[:location]
    if user.save
      login(user)
      flash[:notice] = "Welcome to Shitter, #{user[:username]}"
      redirect to('/')
    else
      flash[:notice] = "There was an error registering" 
      redirect to('/register')
    end
  else
    flash[:notice] = "There was an error registering"
    redirect to('/register')
  end
   
end

get '/search' do
  must_be_logged_in
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
  must_be_logged_in
  protect(params[:id])
  @user = User[params[:id]]
  haml :edit
end

post '/users/:id' do
  must_be_logged_in
  protect(params[:id])
  upd = {}
  [:location, :aboutme].each do |k|
    upd["#{k}"] = sanity(params["#{k}"])
  end

  @user = User[params[:id]]

  if not params[:password].empty?
    upd[:hash] = User.hash_val(@user[:username], params[:password])
  end
  @user.update(upd)
  logout
  login(@user)
  flash[:notice] = "Values have been updated"
  redirect to("/users/#{@user[:id]}/edit")
end

post '/sheets' do
  # someone made a sheet
  must_be_logged_in
  if !params[:attachment].nil? &&  !params[:attachment].empty? &&  !(params[:attachment][:filename] =~ /.*\.(jpg|jpeg)$/i)
    flash[:notice] = "Failed to sheet. Attachment must be a jpg"
    redirect to('/')
  end
  filename = ""
  if not params[:attachment].nil?
    File.open("./public/#{params[:attachment][:filename]}", "w") do |f|
      f.write(params[:attachment][:tempfile].read)
    end
    filename = params[:attachment][:filename]
  end
  sheet = Sheet.new :content => sanity(params[:content]), :created_at => Time.now, :attachment => filename 
  sheet[:user_id] = current_user[:id]
  sheet.save
  flash[:notice] = "Sheet has been made"
  redirect to('/')
end

get '/pics/*' do
  @pic = params[:splat].first
  erb :pic
end
