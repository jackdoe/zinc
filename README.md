## git clone https://github.com/jackdoe/zinc.git

directory structure:

default routes `(GET|POST) /controller/action/*`,
so `GET http://localhost/post/show/1` will make instance of `app/c/PostController.rb` and call `get_show(1)` and if `@output` is empty it will render `app/v/post/show.erb`

```
app/
app/conf/ #configuration (extra routes, database connections etc..)
app/m/ # models
app/v/ #views
app/c/ #conrollers
```
