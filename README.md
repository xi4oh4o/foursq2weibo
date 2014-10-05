foursq2weibo
============

同步4sq签到至微博

> 程序由Sinatra编写数据可保存与Postgres或SQLite3

#### 如何运行
=============
1. 重命名 `config-example.yml` 到 `config.yml` 并填入申请的API信息
2. 执行 `bundle install` 安装依赖库
3. 执行`rake db:migrate` 建立表结构
4. 执行 `ruby app.rb` 访问 `http://localhost:4567`

#### 回调地址
============
* Foursquare: `http://your_host.com/redirect_uri`
* Weibo: `http://your_host.com/wei_redirect`
* Foursquare Push: `https://your_host.com/handle_push`

#### 如何部署在Heroku
=====================
1. `cd foursq2weibo`
2. `heroku git:remote -a foursqtoweibo`
3. `git push -u heroku master`
4. `heroku addons:add heroku-postgresql:hobby-dev`
5. `heroku rake db:migrate`
