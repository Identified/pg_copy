Gem::Specification.new do |s|
  s.name              = "pg_copy"
  s.version           = "0.0.1"
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Osbert", "Phil"]
  s.email             = ["phil@identified.com"]
  s.homepage          = "https://github.com/Identified/pg_copy"
  s.summary           = "Add pg_copy class method to ActiveRecord::Base to provide PostgreSQL
  COPY support for faster bulk insertion of data."
  s.description       = "Add pg_copy class method to ActiveRecord::Base to provide PostgreSQL
  COPY support for faster bulk insertion of data."
  
 
  # The list of files to be contained in the gem 
  s.files         = `git ls-files`.split("\n")
  s.require_path = 'lib'
end