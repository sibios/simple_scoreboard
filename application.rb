#!/usr/bin/ruby
require 'sinatra'
require 'sinatra/contrib'
#require 'sinatra/captcha'
require 'dm-core'
require 'dm-aggregates'
require 'dm-validations'
require 'dm-migrations'
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/database.db")

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
end

class Solve
  include DataMapper::Resource
  property :id,         Serial
  property :flag_name,  String
  property :team_name,  String
  property :points,     Integer
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
  
  @flag1 = Flag.new(:secret => "First", :value => 5, :name => "The First Flag")
  @flag2 = Flag.new(:secret => "Second", :value => 8, :name => "Second Flag")
  @flag3 = Flag.new(:secret => "Third", :value => 12, :name => "Final Test Flag")

  @flag1.save
  @flag2.save
  @flag3.save
end

seed_flags

class ScoreBoard < Sinatra::Base
  enable :sessions

  #main page
  get "/" do
    @solves = Solve.all
    @teams = Team.all
    haml :index, :locals => { :submissions => @solves, :teams => @teams }
  end

  #submit a flag
  post "/flag" do
    #halt(401, "Invalid captcha") unless captcha_pass?

    if Flag.count(:secret => params[:flag]) == 0
      session[:message] = "Nope!  Keep working..."
      redirect to('/')
    end

    if Team.count(:team => params[:team_name].downcase) == 0
      session[:message] = "That team doesn't exist..."
      redirect to('/')
    end

    @team = Team.first(:name => params[:team_name].downcase)
    @flag = Flag.first(:secret => params[:flag])
    if Solve.count(:team => @team.name, :flag_id => @flag.id) != 0
      session[:message] = "That team has already solved that challenge."
      redirect to('/')
    end

    @solve = Solve.new(:flag_id => @flag.id, :team => @team.name, :points => @flag.value)
    @solve.save
    
    @team.score += @flag.value
    @team.save
    
    session[:message] = "Woot woot!  You got #{@flag.value} points!"
    redirect to("/")
  end

  #register a team
  get "/register" do
    haml :register
  end

  post "/register" do
    #halt(401, "Invalid captcha") unless captcha_pass?

    if Team.count(:name => params[:team_name].downcase) == 0
      @team = Team.new(:name => params[:team_name].downcase, :score => 0)
      @team.save
      session[:message] = "Team successfully registered! Get to hacking!"
      redirect to('/')
    else
      session[:message] = "Team failed to register..."
      redirect to('/register')
    end
  end
end
