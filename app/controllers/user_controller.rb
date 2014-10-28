# encoding: utf-8
class UserController < ApplicationController

  def initialize
    super()

    @facebook_app_id = '863608890326822'
    @facebook_app_secret = 'f544d36180bfcd1d8e63613e9e79ea66'
  end

  # Bejelentkezés form megjelenítése
  def show_login

    # ha létezik bejelentkezett felhasználó, akkor megyünk a profil-ra
    unless session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_profile'
    end

  end

  # Profil és kijelentkezés megjelenítése
  def show_profile

    # ha nem létezik bejelentkezett felhasználó, akkor megyünk a login-ra
    if session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_login'
    end

    # felhasználó lekérdezése ( a view számára ), session-ből
    @user = session['user']
  end

  # Bejelentkezett felhasználó kijelentkeztetése (törlése session-ből)
  def logout
    session['user'] = nil

    redirect_to :controller => 'user', :action => 'show_login'
  end

  # Bejelentkezés kezelése
  def login

    # ha létezik bejelentkezett felhasználó, akkor megyünk a profil-ra
    unless session['user'].blank?
      redirect_to :controller => 'user', :action => 'show_profile'
      return
    end

    # token alapú bejelentkezést vizsgál először. Ez az amikor már tudunk egy facebook token-t
    unless params['token'].blank?

      begin

        # token használatával a graph-ból lekérdezzük a felhasználói adatokat
        result = JSON.parse(get_request("https://graph.facebook.com/v2.1/me?access_token=#{params['token']}"))
        unless result['error'].blank?
          raise Exception.new(result['error']['message'])
        end

        # felhasználó lekérdezése/létrehozása
        user = get_user(result)
        if user.blank?
          raise Exception.new('Hiba a felhasználó létrehozásakor')
        end

        # ha minden jó, akkor elmentük munkamenetbe
        session['user'] = user

          # ha meghatározás, vagy url betöltés közben hiba lép fel, akkor azt delegáljuk a loginnak (flash-ben küldi, átirányít)
      rescue Exception => e

        flash[:exception] = 'Facebook bejelentkezesi hiba: ' + e.message
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # ha nem volt probléma, akkor átirányít a profil-ra
      redirect_to :controller => 'user', :action => 'show_profile'
      return
    end

    # ha van code paraméter, akkor ez valószínűleg egy hitelesítéses válasz a facebooktól
    # TODO hiba válasz kezelése
    redirect_url = url_for(:controller => 'user', :action => 'login', :only_path => false)
    unless params['code'].blank?

      # először ellenőrizzük, hogy valid-e a kérés ami visszajött
      if params['state'] != session['facebook_state']

        flash[:exception] = 'Facebook bejelentkezesi hiba!'
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # ha validáltuk, akkor a kapott kódot még be kell váltani tényleges tokenre. Sajnos a facebook annyira egységes, hogy nem az,
      # ezért itt nem json a kimenet, hanem egy query string szerű dolog, ezért az alapján kell feldolgozni
      response = get_request("https://graph.facebook.com/v2.1/oauth/access_token?client_id=#{@facebook_app_id}&redirect_uri=#{redirect_url}&client_secret=#{@facebook_app_secret}&code=#{params['code']}")
      tmp = Rack::Utils.parse_nested_query(response)

      # ha valamiért nincs tokenünk, akkor a hibával visszairányítja a bejelentkezés felületre
      if tmp['access_token'].blank?

        flash[:exception] = 'Facebook bejelentkezesi hiba!'
        redirect_to :controller => 'user', :action => 'show_login'
        return
      end

      # átirányítás ugyan ide, csak mostmár használható access token-el
      redirect_to :controller => 'user', :action => 'login', :token => tmp['access_token']
      return
    end

    # ha nem érekezik token, code vagy state paraméter (token: ekkor már megpróbáljuk a bejelentkezést, code és state pedig facebook-tól jöhet oauth után),
    # akkor indítunk egy új hitelesítést a facebook felé (átirányítással)

    # ez egy biztonsági "token", a CSRF támodások ellen, de nem kötelező a használata
    session['facebook_state'] = (0...50).map { ('a'..'z').to_a[rand(26)] }.join

    # átirányítás a facebook hitelesítő urljére (oauth), és átadjuk (redirect_url), hogy ugyan ide kérjük a választ
    redirect_to "https://www.facebook.com/v2.1/dialog/oauth?scope=public_profile,email&response_type=code&client_id=#{@facebook_app_id}&state=#{session['facebook_state']}&redirect_uri=#{redirect_url}"
  end

  # Regisztráció és/vagy felhasználó azonosítás facebook/email alapján
  def get_user(data)

    # bejövő adat ellenőrzése, hogy tartalmaz-e kereshető adatokat
    if data.blank? || (data['id'].blank? && data['email'].blank?)
      return nil
    end

    # létező felhasználó keresése facebook_id vagy email alapján
    user = User.where('facebook_id = ? OR email = ?', data['id'], data['email']).first
    if user == nil

      # ha nem találunk ilyen felhasználót, akkor létrehozunk egyet az elérhető adatokból
      user = User.create({:name => data['last_name'] + ' ' + data['first_name'], :email => data['email'], :facebook_id => data['id']})
    end

    # létrehozott vagy lekérdezett felhasználó adatainak visszaküldése
    {:id => user.id, :name => user.name, :email => user.email, :facebook_id => user.facebook_id}
  end

  # Get http kérés a megadott url-re, ssl használatával, és válasz tartalom visszadása
  def get_request(url)
    require 'net/http'

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)

    # SSL használata, illetve a kapcsolatot létesítő felek hitelesítésének kikapcsolása (localhost környezet miatt, éles használatra ez a verify_mode nem biztonságos!)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # kérés végrehajtása
    request = Net::HTTP::Get.new(uri.to_s)
    http.request(request).body
  end
end
