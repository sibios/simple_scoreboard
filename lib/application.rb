#!/usr/bin/ruby
require 'sinatra'
require 'sinatra/contrib'
require 'rack'
require 'rack-flash'
require 'rack-protection'
require 'openssl'
require 'haml'

require './lib/model.rb'

class ScoreBoard < Sinatra::Base
  enable :sessions
  use Rack::Flash, :accessorize => [:notice, :error]

  #config warden for auth
  use Warden::Manager do |config|
    config.serialize_into_session{ |team| team.id }
    config.serialize_from_session{ |id| Team.get(id) }
    config.scope_defaults :default, strategies: [:password], action: '/signup'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['team_name'] && params['password']
    end

    def authenticate!
      team = Team.first(:name => params['team_name'])

      if team.nil?
        fail!("Failed to login as that team")
      elsif team.authenticate(params['password'])
        success!(team)
      else
        fail!("Failed to login as that team")
      end
    end
  end

  configure do
    set :static => true
    set :public_dir => "#{settings.root}/../public"
    set :views => "#{settings.root}/../views"
  end

  #main page - public
  get "/" do
    redirect to('/dashboard') unless env['warden'].nil?
    redirect to('/dashboard') unless env['warden'].user.empty?
    haml :index
  end

  get "/dashboard" do
    @solves = Solve.all(:order => [:time.desc], :limit => 5)
    @teams = Team.all(:order => [:score.desc])
    haml :dashboard, :locals => { :submissions => @solves, :teams => @teams }, :layout => false
  end

  #provide a view for auth
  get "/login" do
    haml :login
  end

  #API end-point for login creds
  post "/login" do
    env['warden'].authenticate!
    flash[:notice] = env['warden'].message

    if session[:return_to].nil?
      redirect to('/')
    else
      redirect session[:return_to]
    end
  end

  #terminate the user's session
  get "/logout" do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:notice] = "Logged out"
    redirect to('/')
  end

  #register a team
  get "/register" do
    haml :register
  end

  post "/register" do
    #halt(401, "Invalid captcha") unless captcha_pass?
    if params[:password] != params[:password_confirm]
      flash[:error] = "Passwords do not match!"
      redirect to('/register')
    end

    if Team.count >= 25
      flash[:error] = "Over capacity!  No new teams are being accepted. :("
      redirect to('/')
    end

    name = params[:team_name].downcase

    if Team.count(:name => name) == 0
      @team = Team.new(:name => name, :score => 0, :password => params[:password])
      @team.save
      flash[:notice] = "Team successfully registered! Get to hacking!"
      redirect to('/')
    else
      flash[:error] = "That team exists already.  Be original..."
      redirect to('/register')
    end
  end
  
  #submit a flag
  post "/flag" do
    digest = OpenSSL::Digest.new('sha256')
    digest.update(params[:flag])
    hash = digest.hexdigest()

    if Flag.count(:secret => hash) == 0
      flash[:error] = "Nope!  Keep working..."
      redirect to('/')
    end

    if Team.count(:name => params[:team_name].downcase) == 0
      flash[:error] = "That team doesn't exist..."
      redirect to('/')
    end

    @team = Team.first(:name => params[:team_name].downcase)
    @flag = Flag.first(:secret => hash)

    if Solve.count(:team => @team, :flag => @flag.name) != 0
      flash[:error] = "That team has already solved that challenge."
      redirect to('/')
    end

    @solve = Solve.new(:team => @team, :flag => @flag.name, :points => @flag.value, :time => Time.now)
    @solve.save
    
    @team.score += @flag.value
    @team.save
    
    flash[:notice] = "Woot woot!  You got #{@flag.value} points!"
    redirect to("/")
  end

end
