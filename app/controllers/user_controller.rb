class UserController < ApplicationController

  def show_login

    if session['user']
      redirect_to :controller => 'user', :action => 'show_profile'
    end

  end

  def show_profile

    if session['user'] == nil
      redirect_to :controller => 'user', :action => 'show_login'
    end

    @user = session['user']

  end

  def login
    session['user'] = { :id => 10, :name => "Nagy Samu", :email => "nagy.samu222@gmail.com", :facebook_id => 10000000000134 }

    redirect_to :controller => 'user', :action => 'show_profile'
  end

  def logout
    session['user'] = nil

    redirect_to :controller => 'user', :action => 'show_login'
  end
end
