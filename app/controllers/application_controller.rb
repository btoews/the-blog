class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def login_as(user)
    @current_user = user
    session[:user_id] = user.id
  end

  def current_user
    return @current_user if defined? @current_user
    @current_user = User.find_by_id session[:user_id]
  end
  helper_method :current_user

  def logged_in?
    !!current_user
  end
  helper_method :logged_in?

  def admin?
    logged_in? && current_user.admin?
  end
  helper_method :admin?

  def authenticated_only
    access_denied unless logged_in?
  end

  def anonymous_only
    access_denied if logged_in?
  end

  def admin_only
    access_denied unless admin?
  end

  def access_denied
    render(status: 401, text: "access denied")
  end
end
