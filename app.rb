require 'json'
require 'erb'
require 'time'
require 'yaml'
require 'faraday'
require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require './environments'

I18n.enforce_available_locales = true

enable :sessions

helpers do
  def getConf
    @conf = YAML.load(File.open('config.yml'))
  end
end


class Auth < ActiveRecord::Base
  validates :username, uniqueness: true
  validates :username, :password, presence: true
end

def parseToken(url, method = 'get')
  response = (method =='get') ? Faraday.get(url) : Faraday.post(url)
  response_hash = JSON.parse(response.body)
  return response_hash
end

def encrypt(password)
  Digest::SHA256.hexdigest(password)
end

# Login Authentication

get('/login') do
  if session['username']
    redirect '/'
  end
  erb :"user/login"
end

post '/login' do
  if params[:auth]
    @user = Auth.find_by(username: params[:auth]['username'])
    if @user
      if ( params[:auth]['username'] == @user.username &&
        encrypt(params[:auth]['password']) == @user.password )
        session['username'] = params[:auth]['username']
        redirect '/', :notice => '您已成功登录!'
      else
        redirect '/login', :error => ['授权验证失败.']
      end
    end
    redirect '/login', :error => ['当前用户不存在.']
  end
end

# User registration

get ('/user/create') do
  if session['username']
    redirect '/'
  end

  erb :"user/create"
end

post '/user/create' do
  params[:auth]['password'] =
    encrypt(params[:auth]['password'])
  @auth = Auth.new(params[:auth])
  if @auth.save
    session['username'] = params[:auth]['username']
    redirect '/', :notice => 'Congrats! 您可以进行应用API授权了.'
  else
    redirect '/user/create', :error => @auth.errors.full_messages
  end
end

# OAuth2 Authorization verification
get ('/') do
  if session['username']
    @auth = Auth.find_by(username: session['username'])
    if @auth
      time = @auth.updated_at + 3600
      if time < Time.now
        @auth.weibo_token = ''
        @auth.save
      end
    end
  else
    redirect '/login', :notice => '请先登录!'
  end

  erb :index
end

# Foursquare callback uri
get '/redirect_uri' do
  url = "https://foursquare.com/oauth2/access_token?client_id=" +
  "#{getConf['Foursquare']['client_id']}&client_secret=" +
  "#{getConf['Foursquare']['client_secret']}&grant_type=" +
  "authorization_code&redirect_uri=" +
  "http://foursqtoweibo.herokuapp.com/redirect_uri&code=#{params[:code]}"

  @user = Auth.find_by(username: session['username'])
  @user.foursquare_token = parseToken(url)['access_token']
  user_url = "https://api.foursquare.com/v2/users/self?oauth_token=" +
      "#{@user.foursquare_token}&v=20141005"
  @user.foursquare_id = parseToken(user_url)['response']['user']['id']

  unless @user.save
    logger.warning "Foursquare token save fail"
  end
  redirect '/', :notice => 'Foursquare 授权成功'
end

# Foursquare push handle
post '/handle_push' do
  checkin_hash = JSON.parse(params[:checkin])
  foursq_id = checkin_hash['user']['id']
  @auth = Auth.find_by(foursquare_id: foursq_id)

  api = "https://api.weibo.com/2/statuses/update.json?access_token=" +
    "#{@auth.weibo_token}"

  Faraday.post(api, { :status =>
                      "I'm at #{checkin_hash['venue']['name']}!
                    http://foursquare.com/user/#{checkin_hash['user']['id']}",
                      :lat => "#{checkin_hash['venue']['location']['lat']}",
                      :long => "#{checkin_hash['venue']['location']['lng']}"})
end

# Weibo callback uri
get '/wei_redirect' do
  url = "https://api.weibo.com/oauth2/access_token?client_id=" +
    "#{getConf['Weibo']['key']}&client_secret=" +
    "#{getConf['Weibo']['secret']}&grant_type=" +
    "authorization_code&redirect_uri=" +
    "http://foursqtoweibo.herokuapp.com/wei_redirect&code=#{params[:code]}"

  @user = Auth.find_by(username: session['username'])
  @user.weibo_token = parseToken(url, 'post')['access_token']

  unless @user.save
    logger.warning "Weibo token save fail"
  end

  redirect '/', :notice => 'Weibo 授权成功'
end
