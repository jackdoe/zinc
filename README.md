## zinc (require sinatra)
```
$ gem install sinatra thin
$ git clone https://github.com/jackdoe/zinc.git
$ cd zinc
$ ruby zinc.rb generate controller post
$ vim app/c/PostController.rb # add 'def get_show(id); end' inside PostController class
$ vim app/v/post/show.erb # add bazinga! # or echo 'bazinga!' > app/v/post/show.erb
$ thin start -p 3456
$ curl http://localhost:3456/post/show/5
```

default routes `(GET|POST) /controller/action/*`,
so `GET http://localhost/post/show/1` will make instance of `app/c/PostController.rb` and call `get_show(1)` and if `@output` is empty it will render `app/v/post/show.erb`

directory structure:

```
app/
app/conf/ #configuration (extra routes, database connections etc..)
app/m/ # models
app/v/ #views
app/c/ #conrollers
```

## generate
there is a simple controller/model generator
```
zinc $ ruby zinc.rb generate model animal weight:integer height:integer_not_null_default_4 name:string_not_null_default_unknown
CREATE(directory): ./app
CREATE(directory): ./app/v
CREATE(directory): ./app/m
CREATE(directory): ./app/c
CREATE(directory): ./app/test
CREATE(directory): ./app/conf
CREATE(directory): ./app/db
CREATE(directory): ./app/db/migrate
GENERATE(file):./app/conf/db.rb
CREATE(directory): ./app/test/animal
GENERATE(file):./app/db/migrate/20120909155106_create_animals.rb
GENERATE(file):./app/m/Animal.rb
GENERATE(file):./app/test/animal/Animal.rb
zinc $ cat ./app/db/migrate/20120909155106_create_animals.rb

class CreateAnimals < ActiveRecord::Migration
  def change
    create_table :animals do |t|
      t.integer	:weight, :null => true
      t.integer	:height, :null => false, default: 4
      t.string	:name, :null => false, default: 'unknown'
      t.timestamps
    end
  end
end
zinc $ rake db:migrate
D, [2012-09-09T15:51:20.454169 #10335] DEBUG -- :    (0.2ms)  select sqlite_version(*)
D, [2012-09-09T15:51:20.456075 #10335] DEBUG -- :    (1.5ms)  CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL) 
D, [2012-09-09T15:51:20.456303 #10335] DEBUG -- :    (0.0ms)  PRAGMA index_list("schema_migrations")
D, [2012-09-09T15:51:20.457574 #10335] DEBUG -- :    (1.1ms)  CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version")
D, [2012-09-09T15:51:20.459939 #10335] DEBUG -- :    (0.7ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" 
I, [2012-09-09T15:51:20.460023 #10335]  INFO -- : Migrating to CreateAnimals (20120909155106)
D, [2012-09-09T15:51:20.460223 #10335] DEBUG -- :    (0.1ms)  begin transaction
==  CreateAnimals: migrating ==================================================
-- create_table(:animals)
D, [2012-09-09T15:51:20.466436 #10335] DEBUG -- :    (0.4ms)  CREATE TABLE "animals" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "weight" integer, "height" integer DEFAULT 4 NOT NULL, "name" varchar(255) DEFAULT 'unknown' NOT NULL, "created_at" datetime NOT NULL, "updated_at" datetime NOT NULL) 
   -> 0.0057s
==  CreateAnimals: migrated (0.0058s) =========================================

D, [2012-09-09T15:51:20.467071 #10335] DEBUG -- :    (0.1ms)  INSERT INTO "schema_migrations" ("version") VALUES ('20120909155106')
D, [2012-09-09T15:51:20.468364 #10335] DEBUG -- :    (1.1ms)  commit transaction
```
we can also generate empty controllers
```
$ ruby zinc.rb generate controller person
CREATE(directory): ./app/test/person
CREATE(directory): ./app/v/person
GENERATE(file):./app/c/PersonController.rb
GENERATE(file):./app/test/person/PersonController.rb
```
## example app/conf/main.rb
```
require 'active_record'
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',:database => "#{APP}/database.sqlite3")
# example of adding default controller/action to custom route

class Zinc
	get '/' do
		params[:controller] = 'post'
		params[:action] = 'list'
		self.process
	end
end
```

or split `main.rb` into `db.rb` and `routes.rb`

```
db.rb:
require 'active_record'
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',:database => "#{APP}/database.sqlite3")

routes.rb:
class Zinc
	get '/' do
		params[:controller] = 'post'
		params[:action] = 'list'
		self.process
	end
end
```
