require 'dm-core'
require 'dm-aggregates'
require 'dm-validations'
require 'dm-migrations'
require 'bcrypt'

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

  property :id,       Serial, :key => true
  property :name,     String, :required => true
  property :password, BCryptHash
  property :score,    Integer
  
  has n, :solves, "Solve"

  def authenticate(attempt)
    self.password == attempt
  end
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

