require 'active_record'
db_path = File.absolute_path('../../tmp', __dir__)
FileUtils.mkdir_p(db_path)
ActiveRecord::Base.establish_connection(adapter:  'sqlite3', database: "#{db_path}/test.db")
