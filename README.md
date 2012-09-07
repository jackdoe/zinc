## zinc (require sinatra)
```
$ gem install sinatra thin
$ git clone https://github.com/jackdoe/zinc.git
$ cd zinc
$ ruby zinc.rb generate post
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
