#!/usr/bin/ruby
require 'sinatra'
require 'sinatra-contrib'
require 'sinatra-captcha'
require 'dm-core'
require 'dm-validations'
require 'dm-migration'
require 'dm-sqlite-adapter'
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
end

class Solve
  include DataMapper::Resource
  property :id,       Serial
  property :flag_id,  Integer
  property :points,   Integer
end

DataMapper.finalize
Flag.auto_upgrade!
Team.auto_upgrade!
Solve.auto_upgrade!

class ScoreBoard < Sinatra::Base
  #main page
  get "/" do
    haml :index
  end

  #submit a flag
  post "/flag" do
  end

  #register a team
  post "/register" do
  end
end
