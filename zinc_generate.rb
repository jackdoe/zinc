#ugly as hell
def generate
  command = ARGV.shift
  if command =~ /^(g|generate)$/

    mkdir = lambda do |name|
      Dir.mkdir(name) and puts "CREATE(directory): #{name}" unless Dir.exists?(name)
    end
    write = lambda do |file,s|
      File.open(file, 'w') {|f| f.write(s) } and puts "GENERATE(file):#{file}" unless File.exists?(file)
    end
    PATHS.each_value { |x| mkdir.call(x)}
    write.call(File.join(PATHS[:conf],"db.rb"),%Q{
require 'active_record'
require 'logger'
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',:database => File.join(PATHS[:db],'database.sqlite3'))
ActiveRecord::Base.logger = Logger.new STDOUT}
    )

    model = (ARGV.shift =~ /^(m|model)$/)
    if x = ARGV.shift
      x = x.sanitize.downcase.capitalize
      dir = x.downcase
      mkdir.call File.join(PATHS[:test],dir)
      if model
        require 'active_support/inflector'
        table = dir.pluralize
        attributes = []
        quotize = lambda do |x|
          return x if x == "true" || x == "false"
          return x if !(Float(x) rescue nil).nil?
          return "'#{x}'"
        end
        fields = ARGV.map do |a| 
          name,t = a.split(':')
          null = t.gsub!(/_not_null/,"").nil? # remove _not_null if it was there
          (t,default) = t.split("_default_")
          attributes << ":#{name}"
          "      t.#{t}\t:#{name}, :null => #{null}" + (default ? ", default: #{quotize.call default}" : "") 
        end
        write.call(File.join(PATHS[:migrate],"#{Time.now.strftime '%Y%m%d%H%M%S'}_create_#{table}.rb"),%Q{
class Create#{x.pluralize} < ActiveRecord::Migration
  def change
    create_table :#{table} do |t|
#{fields.join("\n")}
      t.timestamps
    end
  end
end
  })
        write.call(File.join(PATHS[:m],"#{x}.rb"), "class #{x} < ActiveRecord::Base\n  attr_accessor #{attributes.join(",")}\nend\n")
        write.call(File.join(PATHS[:test],dir,"#{x}.rb"), "class #{x}Test < Test::Unit::TestCase\nend\n")
      else
        mkdir.call File.join(PATHS[:v],dir)
        c = "#{x}Controller"
        write.call(File.join(PATHS[:c],"#{c}.rb"), "class #{c} < Controller\nend\n")
        write.call(File.join(PATHS[:test],dir,"#{c}.rb"), "class #{c}Test < Test::Unit::TestCase\n  include Rack::Test::Methods\n  def app\n    Zinc\n  end\nend\n")
      end
    end
  elsif command =~ /^(c|console)$/
    system("irb -r '#{File.join(ROOT,"zinc.rb")}'")
  elsif command =~ /^(t|test)$/
    puts %x{ruby #{File.join(ROOT,"zinc_test.rb")}}
  end
end