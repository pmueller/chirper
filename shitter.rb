require 'haml'
require 'ostruct'
require 'rack-flash'
require 'sequel'
require 'sinatra/base'

class Chirper < Sinatra::Base
  enable :sessions
  use Rack::Flash, :sweep => true

  error do
    '500 error!'
  end

  not_found do
    '404 not found'
  end

  configure do
    S = OpenStruct.new(
      :user_cookie_key => 'chirper_user_cookie',
      :hash_cookie_key => 'chirper_hash_cookie'
    )

    db = Sequel.connect('sqlite://s.db')
    unless db.table_exists?(:chirps)
      db.create_table :chirps do
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
  # sublassing Sequel::Model fails unless db is already connected
  require 'chirp'
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

    def ensure_user_logged_in
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
    ensure_user_logged_in

    @chirps = Chirp.reverse_order(:created_at)
    haml :index
  end

  get '/login' do
    redirect to('/') unless not logged_in?
    haml :login
  end

  post '/login' do
    redirect to('/') unless not logged_in?
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
    ensure_user_logged_in

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

    if !params[:password].empty? && params[:password] == params[:password_confirm] && !params[:username].empty?
      hash = User.hash_val(params[:username], params[:password])
      user = User.new :username => params[:username], :hash => "#{hash}", :aboutme => params[:aboutme], :location => params[:location]
      if user.save
        login(user)
        flash[:notice] = "Welcome to Chirper, #{user[:username]}"
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
    ensure_user_logged_in

    @search_term = params[:search_term]
    if @search_term.nil?
      @results = []
    else
      @search_term = search_sanity(@search_term)
      @results = Chirp.filter(Sequel.like(:content, "%#{@search_term}%"))
    end
    haml :search
  end

  get '/users/:id/edit' do
    ensure_user_logged_in

    protect(params[:id])
    @user = User[params[:id]]
    haml :edit
  end

  post '/users/:id' do
    ensure_user_logged_in

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

  post '/chirps' do
    ensure_user_logged_in

    if !params[:attachment].nil? &&  !params[:attachment].empty? &&  !(params[:attachment][:filename] =~ /.*\.(jpg|jpeg)$/i)
      flash[:notice] = "Failed to chirp. Attachment must be a jpg"
      redirect to('/')
    end
    filename = ""
    if not params[:attachment].nil?
      File.open("./public/#{params[:attachment][:filename]}", "w") do |f|
        f.write(params[:attachment][:tempfile].read)
      end
      filename = params[:attachment][:filename]
    end
    chirp = Chirp.new :content => sanity(params[:content]), :created_at => Time.now, :attachment => filename
    chirp[:user_id] = current_user[:id]
    chirp.save
    flash[:notice] = "Chirp has been made"
    redirect to('/')
  end

  get '/pics/*' do
    @pic = params[:splat].first
    erb :pic
  end

  run! if app_file == $0
end
