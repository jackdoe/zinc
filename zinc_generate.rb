require 'active_support/inflector'

#ugly as hell
def __write(file,s)
  File.open(file, 'w') {|f| f.write(s) } and puts "GENERATE(file):#{file}" unless File.exists?(file)
end
def __mkdir(name)
  Dir.mkdir(name) and puts "CREATE(directory): #{name}" unless Dir.exists?(name)
end
def __quotize(x)
  return "nil" if x.nil?
  return x if x == "true" || x == "false"
  return x if !(Float(x) rescue nil).nil?
  return "'#{x}'"
end
def __migration_file(s)
  prefix = "#{Time.now.strftime '%Y%m%d%H%M%S'}#{Time.now.usec}"
  File.join(PATHS[:migrate],"#{prefix}_#{s}.rb")
end
def __s_to_field(s, table = "")
    name,t = s.split(':')
    raise "fields must be in form 'field_name:field_type' not '#{s}'" unless name && t
    null = t.gsub!(/_not_null/,"").nil? # remove _not_null if it was there
    unique = !t.gsub!(/_unique/,"").nil?
    (t,default) = t.split("_default_")
    default = __quotize default
    supported = ['string','text','integer','float','decimal','datetime','timestamp','time','date','binary','boolean']
    raise "unknown type '#{t}'' supported: #{supported.inspect}" unless supported.include?(t)
    params = "null: #{null}, default: #{default}"
    {
      type: t,
      name: name,
      null: null,
      unique: unique,
      default: default,
      create: "      t.#{t}\t:#{name}, #{params}",
      add:    "    add_column :#{table}, :#{name}, :#{t}, #{params}",
      remove: "    remove_column :#{table}, :#{name}"
    }
end
def migrate(key,args = [])
  table = key.downcase.pluralize
  attributes = []
  validators = []
  if key =~ /^(add|remove|rename)_(.*)?_(to|from)_(.*)$/ || args.count == 0
    file = __migration_file(key)
    up = []
    down = []
    table = $4
    action = $1
    if action == 'rename'
      column_name = $2
      if new_column_name = args.shift
        up <<   "    rename_column :#{table},:#{column_name}, :#{new_column_name}"
        down << "    rename_column :#{table},:#{new_column_name}, :#{column_name}"
      end
    else
      args.each do |a|
        f = __s_to_field(a,table)
        if action == 'add'
          up << f[:add]
          down << f[:remove]
        else
          up << f[:remove]
          down << f[:add]
        end
      end
    end
    text = <<-EOL
class #{key.split("_").map { |x| x.downcase.capitalize }.join("")} < ActiveRecord::Migration
  def up
#{up.join("\n")}
  end
  def down
#{down.join("\n")}
  end
end
EOL
  else
    file = __migration_file("create_#{table}")
    fields = args.map do |a| 
      f = __s_to_field(a)
      attributes << ":#{f[:name]}"
      validators << "validates :#{f[:name]}, :presence => true" if !f[:null]
      validators << "validates :#{f[:name]}, :uniqueness => true" if f[:unique]
      f[:create]
    end    
    text = <<-EOL
class Create#{table.capitalize} < ActiveRecord::Migration
  def change
    create_table :#{table} do |t|
#{fields.join("\n")}
      t.timestamps
    end
  end
end
EOL
  end
  __write file,text
  return attributes,validators
end
def generate(argv = ARGV)
  command = argv.shift
  if command =~ /^(g|generate)$/
    PATHS.each_value { |x| __mkdir(x)}
    __write(File.join(PATHS[:conf],"db.rb"),%Q{
require 'active_record'
require 'logger'
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',:database => File.join(PATHS[:db],'database.sqlite3'))
ActiveRecord::Base.logger = Logger.new STDOUT}
    )
    subcommand = argv.shift
    if subcommand =~ /^(model|controller)$/
      if x = argv.shift
        x = x.sanitize.downcase.capitalize
        dir = x.downcase
        __mkdir (File.join(PATHS[:test],dir))
        if subcommand == 'model'
          attributes,validators = migrate(x,argv)
          attributes_text = (attributes.count > 0 ? "attr_accessible #{attributes.join(",")}" : "")
          validators_text = (validators.count > 0 ? validators.map { |v| v = "  #{v}"}.join("\n") : "")
          __write File.join(PATHS[:m],"#{x}.rb"), "class #{x} < ActiveRecord::Base\n  #{attributes_text}\n#{validators_text}\nend\n"
          __write File.join(PATHS[:test],dir,"#{x}.rb"), "class #{x}Test < Test::Unit::TestCase\nend\n"
        else
          __mkdir (File.join(PATHS[:v],dir))
          c = "#{x}Controller"
          __write File.join(PATHS[:c],"#{c}.rb"), "class #{c} < Controller\nend\n"
          __write File.join(PATHS[:test],dir,"#{c}.rb"), "class #{c}Test < Test::Unit::TestCase\n  include Rack::Test::Methods\n  def app\n    Zinc\n  end\nend\n"
        end
      end
    elsif subcommand =~ /^(migrate|migration)$/
      migrate(argv.shift,argv)
    else
      puts "unknown subcommand #{subcommand}"
    end        
  elsif command =~ /^(c|console)$/
    system("irb -r '#{File.join(ROOT,"zinc.rb")}'")
  elsif command =~ /^(t|test)$/
    puts %x{ruby #{File.join(ROOT,"zinc_test.rb")}}
  end
end