require 'rubygems'

# TODO: autovalidation hooks are needed badly,
#       otherwise plugin devs will have to abuse
#       alising and load order even further and it kinda makes
#       me sad -- MK

# use local dm-core if running from a typical dev checkout.
lib = File.join('..', '..', 'dm-core', 'lib')
$LOAD_PATH.unshift(lib) if File.directory?(lib)
require 'dm-core'

# use local dm-validations if running from a typical dev checkout.
lib = File.join('..', 'dm-validations', 'lib')
$LOAD_PATH.unshift(lib) if File.directory?(lib)
require 'dm-validations'

# Support running specs with 'rake spec' and 'spec'
$LOAD_PATH.unshift('lib') unless $LOAD_PATH.include?('lib')

require 'dm-types'

def load_driver(name, default_uri)
  return false if ENV['ADAPTER'] != name.to_s

  begin
    DataMapper.setup(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
    DataMapper::Repository.adapters[:default] =  DataMapper::Repository.adapters[name]
    true
  rescue LoadError => e
    warn "Could not load do_#{name}: #{e}"
    false
  end
end

ENV['ADAPTER'] ||= 'sqlite3'

HAS_SQLITE3  = load_driver(:sqlite3,  'sqlite3::memory:')
HAS_MYSQL    = load_driver(:mysql,    'mysql://localhost/dm_core_test')
HAS_POSTGRES = load_driver(:postgres, 'postgres://postgres@localhost/dm_core_test')


DEPENDENCIES = {
  'bcrypt'    => 'bcrypt-ruby',
  'fastercsv' => 'fastercsv',
  'json'      => 'json',
  'stringex'  => 'stringex',
  'uuidtools' => 'uuidtools',
}

def try_spec
  begin
    yield
  rescue NameError
    # do nothing
  rescue LoadError => error
    raise error unless lib = error.message.match(/\Ano such file to load -- (.+)\z/)[1]

    gem_location = DEPENDENCIES[lib] || raise("Unknown lib #{lib}")

    warn "[WARNING] Skipping specs using #{lib}, please do: gem install #{gem_location}"
  end
end
