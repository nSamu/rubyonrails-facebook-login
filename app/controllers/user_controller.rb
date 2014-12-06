# encoding: utf-8
class UserController < ApplicationController

  def initialize
    super()

    @facebook_app_id = '863608890326822'
    @facebook_app_secret = 'f544d36180bfcd1d8e63613e9e79ea66'
  end

  # Display login form
  def show_login

    # redirect to the profile if the user is already logged in
    unless session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_profile'
    end

  end

  # Display profile and logout screen
  def show_profile

    # redirect to the login if the user doesn't logged in
    if session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_login'
    end

    # get user data from the session
    @user = session['user']
  end

  # Logout the user
  def logout
    session['user'] = nil

    redirect_to :controller => 'user', :action => 'show_login'
  end

  # Handle login or facebook oauth request/response
  def login

    # redirect to the profile if the user is already logged in
    unless session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_profile'
      return
    end

    # login request with facebook access token
    unless params['token'].blank?

      begin

        # load userdata from the facebook graph with the token
        result = JSON.parse(get_request("https://graph.facebook.com/v2.1/me?access_token=#{params['token']}"))
        unless result['error'].blank?
          raise Exception.new(result['error']['message'])
        end

        # get (or create) the user
        user = get_user(result)
        if user.blank?
          raise Exception.new('User creation error')
        end

        # save user to the session
        session['user'] = user

          # send the error message back to the login screen on exception
      rescue Exception => e

        flash[:exception] = 'Facebook login error: ' + e.message
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # redirect to the profile
      redirect_to :controller => 'user', :action => 'show_profile'
      return
    end

    # check oauth response from facebook
    # TODO hiba válasz kezelése
    redirect_url = url_for(:controller => 'user', :action => 'login', :only_path => false)
    unless params['code'].blank?

      # CSRF attack check (optional)
      if params['state'] != session['facebook_state']

        flash[:exception] = 'Facebook login error!'
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # exchange the 'code' request parameter to token. The response is a query string, not JSON!
      response = get_request("https://graph.facebook.com/v2.1/oauth/access_token?client_id=#{@facebook_app_id}&redirect_uri=#{redirect_url}&client_secret=#{@facebook_app_secret}&code=#{params['code']}")
      tmp = Rack::Utils.parse_nested_query(response)

      # redirect back to the login screen if no access token in the response
      if tmp['access_token'].blank?

        flash[:exception] = 'Facebook login error!'
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # redirect here with a valid token to do the login
      redirect_to :controller => 'user', :action => 'login', :token => tmp['access_token']
      return
    end

    # start a new oauth request when no token (this is when do the login), code or state (from facebook oauth redirect) param

    # generate security "token" against CSRF attacks (optional)
    session['facebook_state'] = (0...50).map { ('a'..'z').to_a[rand(26)] }.join

    # redirect to facebook's oauth url (with a redirect url back to the application)
    redirect_to "https://www.facebook.com/v2.1/dialog/oauth?scope=public_profile,email&response_type=code&client_id=#{@facebook_app_id}&state=#{session['facebook_state']}&redirect_uri=#{redirect_url}"
  end

  # Registrate or detect user based on parameter 'id' or 'email' index value
  def get_user(data)

    # check parameter for searchable data
    if data.blank? || (data['id'].blank? && data['email'].blank?)
      return nil
    end

    # find the user based on facebook_id or email address
    user = User.where('facebook_id = ? OR email = ?', data['id'], data['email']).first
    if user == nil

      # create the user if doesn't exist already
      user = User.create({:name => data['last_name'] + ' ' + data['first_name'], :email => data['email'], :facebook_id => data['id']})
    end

    # return the user data
    {:id => user.id, :name => user.name, :email => user.email, :facebook_id => user.facebook_id}
  end

  # Get http request to the given url parameter (with SSL) and return the response body
  def get_request(url)
    require 'net/http'

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)

    # use SSL for the request, but due to the local environment disable peer verification
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # FIXME remove (or comment out) this line in real production

    # do the request
    request = Net::HTTP::Get.new(uri.to_s)
    http.request(request).body
  end
end
