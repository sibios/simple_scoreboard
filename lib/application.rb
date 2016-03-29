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
  use Rack::Flash, :accessorize => [:notice, :error], :sweep => true

  #config warden for auth
  use Warden::Manager do |config|
    config.serialize_into_session{ |team| team.id }
    config.serialize_from_session{ |id| Team.get(id) }
    config.scope_defaults :default, strategies: [:password], action: '/'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['x-rack.flash'].error = 'lol nope'
    env['REQUEST_METHOD'] = 'GET'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['team_name'] && params['password']
    end

    def authenticate!
      team = Team.first(:name => params['team_name'].downcase)

      if team.nil?
        fail!("Failed to login as that team")
      elsif team.authenticate(params['password'])
        success!(team, "Successfully logged in.  Get to hacking!")
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

  def authenticated?(warden)
    return false if warden.nil?
    return false if warden.user.nil?

    return true
  end
  
  def admin?(warden)
    return false unless authenticated?(warden)
    warden.user.name == "admin"
  end

  #main page - public
  get "/" do
    @solves = Solve.all(:order => [:time.desc], :limit => 5)
    @teams = Team.all(:order => [:score.desc])
    
    if authenticated?(env['warden'])
      @user = Team.first(:name => env['warden'].user.name.downcase)
      if @user.locked
        env['warden'].raw_session.inspect
        env['warden'].logout
        flash[:error] = "You have been banned due to abuse."
        redirect to('/')
      end

      @flags = Flag.all()
      @cat1 = Flag.all(:category => "cat1", :order => [:value.asc])
      @cat2 = Flag.all(:category => "cat2", :order => [:value.asc])
      @cat3 = Flag.all(:category => "cat3", :order => [:value.asc])
      @cat4 = Flag.all(:category => "cat4", :order => [:value.asc])

      @cat_map = {
        :cat1 => "Pwnable",
        :cat2 => "Reversing",
        :cat3 => "Web",
        :cat4 => "Trivia"
      }
      
      if admin?(env['warden'])
        @team_table = [[],[],[]]
        @team_counter = 0
        @teams.each do |team|
          next if team.name == "admin"
          @team_table[(@team_counter % 3)] << team
        end
        #@team_table << @temp_row
        haml :admin, :layout => :player_layout, :locals => {
          :submissions => @solves, :teams => @teams, :flags => @flags, :flags_cat1 => @cat1,
          :flags_cat2 => @cat2, :flags_cat3 => @cat3, :flags_cat4 => @cat4,
          :user => @user, :team_table => @team_table, :category_map => @cat_map }
      else
        @team_solves = []
        @user.solves.each do |solve|
          flag = Flag.first(:name => solve.flag)
          @team_solves << flag.id
        end
        haml :player, :layout => :player_layout, :locals => { 
          :submissions => @solves, :teams => @teams, :user => @user, :flags_cat1 => @cat1,
          :flags_cat2 => @cat2, :flags_cat3 => @cat3, :flags_cat4 => @cat4, :solves => @team_solves,
          :flags => @flags, :category_map => @cat_map }
      end
    else
      haml :_dashboard, :locals => { :submissions => @solves, :teams => @teams }
    end
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

  # only if not authenticated
  post "/register" do
    redirect to('/') if authenticated?(env['warden'])

    if params[:team_name] == ""
      flash[:error] = "Really, dude? Pick a team name!"
      redirect to('/register')
    end

    if params[:password] == ""
      flash[:error] = "Really, dude? Use a password."
      redirect to('/register')
    end

    #confirm matching passwords
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
      @team = Team.new(:name => name, :display => params[:team_name], :score => 0, :password => params[:password])
      @team.save
      flash[:notice] = "Team successfully registered! Get to hacking!"
      redirect to('/')
    else
      flash[:error] = "That team exists already.  Be original..."
      redirect to('/register')
    end
  end
  
  #submit a flag
  #   only available to authenticated users
  post "/flag" do
    redirect to('/') unless authenticated?(env['warden'])

    @user = Team.first(:name => env['warden'].user.name.downcase)
    if @user.locked
      env['warden'].raw_session.inspect
      env['warden'].logout
      flash[:error] = "You have been banned due to abuse."
      redirect to('/')
    end

    digest = OpenSSL::Digest.new('sha256')
    digest.update(params[:flag])
    hash = digest.hexdigest()

    if Flag.count(:secret => hash) == 0
      flash[:error] = "Nope!  Keep working..."
      redirect to('/')
    end

    @team = Team.first(:name => env['warden'].user.name.downcase)
    @flag = Flag.first(:secret => hash)

    unless @flag.active
      # valid team had a valid flag, but challenge wasn't active yet...
      flash[:error] = "Nope!  Keep working..."
      redirect to('/')
    end

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

  # Admin functionality
  #   must be authenticated, must be Admin
  get "/admin" do
    redirect to('/') unless admin?(env['warden'])
    @solves = Solve.all(:order => [:time.desc], :limit => 5)
    @teams = Team.all(:order => [:score.desc])
    @flags = Flag.all()
    haml :admin, :layout => :player_layout, :locals => { :submissions => @solves, :teams => @teams, :flags => @flags }
  end

  # POST /admin/team/:id
  post "/admin/team/:id" do
    redirect to('/') unless admin?(env['warden'])
    @team = Team.first(:id => params[:id])
    if @team.name == "admin"
      flash[:error] = "Changes to admin not allowed"
      redirect to('/admin')
    end

    if params[:name] != ""
      @team.display = params[:name]
    end

    if params[:lockout] != ""
      @team.locked = (params[:lockout] == "enable")
    end

    if params[:score] != ""
      @team.score = params[:score]
    end

    if params[:password] != ""
      @team.password = params[:password]
    end

    @team.save
    flash[:notice] = "Team \"#{@team.display}\" updated"
    redirect to('/')
  end

  # POST /admin/flag/:id
  post "/admin/flag/:id" do
    redirect to('/') unless admin?(env['warden'])
    @flag = Flag.first(:id => params[:id])

    if params[:name] != ""
      @flag.name = params[:name]
    end

    if params[:secret] != ""
      digest = OpenSSL::Digest.new('sha256')
      digest.update(params[:secret])
      hash = digest.hexdigest()
      @flag.secret = hash
    end

    if params[:value] != ""
      @flag.value = params[:value]
    end

    if params[:active] != ""
      @flag.active = (params[:active] == "enable")
    end

    if params[:category] != ""
      @flag.category = :cat1 if (params[:category] == "Category 1")
      @flag.category = :cat2 if (params[:category] == "Category 2")
      @flag.category = :cat3 if (params[:category] == "Category 3")
      @flag.category = :cat4 if (params[:category] == "Category 4")
    end

    @flag.save
    flash[:notice] = "Flag \"#{@flag.name}\" updated"
    redirect to('/')
  end
end
