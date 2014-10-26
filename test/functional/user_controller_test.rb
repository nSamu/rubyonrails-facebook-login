require 'test_helper'

class UserControllerTest < ActionController::TestCase
  test "should get show_login" do
    get :show_login
    assert_response :success
  end

  test "should get show_profile" do
    get :show_profile
    assert_response :success
  end

  test "should get login" do
    get :login
    assert_response :success
  end

  test "should get logout" do
    get :logout
    assert_response :success
  end

end
