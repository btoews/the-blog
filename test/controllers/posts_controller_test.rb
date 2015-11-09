require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  setup do
    @post = Post.first
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:posts)
  end

  test "should not show edit links if not authed" do
    get :index
    assert_response :success
    assert_select "li.post" do |lis|
      lis.each do |li|
        assert_select li, "a", 1
      end
    end
  end

  test "should show edit links if authed" do
    get :index, :token => Rails.application.config.auth_token
    assert_response :success
    assert_select "li.post" do |lis|
      lis.each do |li|
        assert_select li, "a", 2 do |as|
          assert_equal "(edit)", as.last.text
        end
      end
    end
  end


  test "should get post" do
    get :show, :id => @post.id
    assert_response :success
    assert_select ".name", @post.name
    assert_select "div.body", @post.body
  end

  test "should not show post form when authenticated" do
    get :new
    assert_response :unauthorized
  end

  test "should show post form when authenticated" do
    get :new, :token => Rails.application.config.auth_token
    assert_response :success
    assert_select "form"
  end

  test "should create post when authenticated" do
    post_params = {:name => "test post", :body => "test post body"}
    assert_difference("Post.count", 1) do
      post :create, :token => Rails.application.config.auth_token, :post => post_params
      assert_redirected_to post_path(Post.last)
    end
  end

  test "validates post fields" do
    post_params = {:name => nil, :body => "test post body"}
    assert_no_difference("Post.count") do
      post :create, :token => Rails.application.config.auth_token, :post => post_params
      assert_response :success
      assert_select ".flash", "Name can't be blank"
    end
  end
end
