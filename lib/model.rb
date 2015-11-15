require 'dm-core'
require 'dm-aggregates'
require 'dm-validations'
require 'dm-migrations'
require 'dm-types'
require 'bcrypt'
require 'openssl'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/database.db")
DataMapper::Property::String.length(255)

class Flag
  include DataMapper::Resource
  property :id,     Serial
  property :secret, String
  property :value,  Integer
  property :name,   String
  property :active, Boolean
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
 
  flags = YAML.load_file('./conf/flags.yml')
  flags.each do |flag_data|
    sha = OpenSSL::Digest.new('sha256')
    sha.update(flag_data[:secret])
    @flag = Flag.new(
      :secret => sha.hexdigest,
      :value => flag_data[:value],
      :name => flag_data[:name],
      :active => flag_data[:active] || false      # assume disabled unless set otherwise
    )
    @flag.save
  end
end

def add_admin
  begin
    admin_pass = YAML.load_file('./conf/config.yml')
    admin_pass = admin_pass["admin_password"]
  end

  puts "[+] Creating admin user..."
  @admin = Team.new(
    :name => "admin",
    :password => admin_pass,
    :score => -1
  )
  @admin.save
end
