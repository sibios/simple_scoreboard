#!/usr/bin/ruby
require 'sinatra'
require 'sinatra/contrib'
require 'rack-flash'
require 'dm-core'
require 'dm-aggregates'
require 'dm-validations'
require 'dm-migrations'
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/database.db")
DataMapper::Property::String.length(255)
class Flag
  include DataMapper::Resource
  property :id,     Serial
  property :secret, String
  property :value,  Integer
  property :name,   String
end

class Team
  include DataMapper::Resource
  property :id,     Serial
  property :name,   String, :required => true
  property :score,  Integer

  has n, :solves, "Solve"
end

class Solve
  include DataMapper::Resource
  property :id,     Serial
  property :points, Integer
  property :flag,   String
  property :time,   DateTime

  belongs_to :team
end

DataMapper.finalize
Flag.auto_upgrade!
Team.auto_upgrade!
Solve.auto_upgrade!

def seed_flags
  unless Flag.count == 0
    puts "[-] Skipping Seeding..."
    return
  end
  puts "[+] Seeding flags..."
 
  flags = YAML.load_file('flags.yml')
  flags.each do |flag_data|
    @flag = Flag.new(
      :secret => flag_data[:secret],
      :value => flag_data[:value],
      :name => flag_data[:name]
    )
    @flag.save
  end
end

seed_flags

class ScoreBoard < Sinatra::Base
  enable :sessions
  use Rack::Flash, :accessorize => [:notice, :error]

  #main page
  get "/" do
    @solves = Solve.all(:order => [:time.desc], :limit => 5)
    @teams = Team.all(:order => [:score.desc])
    haml :index, :locals => { :submissions => @solves, :teams => @teams }
  end

  #submit a flag
  post "/flag" do
    if Flag.count(:secret => params[:flag]) == 0
      flash[:error] = "Nope!  Keep working..."
      redirect to('/')
    end

    if Team.count(:name => params[:team_name].downcase) == 0
      flash[:error] = "That team doesn't exist..."
      redirect to('/')
    end

    @team = Team.first(:name => params[:team_name].downcase)
    @flag = Flag.first(:secret => params[:flag])

    #if Solve.count(:team => @team, :flag => @flag) != 0
    #if Solve.count(Team.all(:name => @team.name).solves.flag(:secret => @flag.secret)) != 0
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

  #register a team
  get "/register" do
    redirect to('/')
  end

  post "/register" do
    #halt(401, "Invalid captcha") unless captcha_pass?

    if Team.count >= 25
      flash[:error] = "Over capacity!  No new teams are being accepted. :("
      redirect to('/')
    end

    if Team.count(:name => params[:team_name].downcase) == 0
      @team = Team.new(:name => params[:team_name].downcase, :score => 0)
      @team.save
      flash[:notice] = "Team successfully registered! Get to hacking!"
      redirect to('/')
    else
      flash[:error] = "That team exists already.  Be original..."
      redirect to('/register')
    end
  end
end
