class SessionsController < ApplicationController
  before_filter :anonymous_only,     only: [:new, :create]
  before_filter :authenticated_only, only: [:destroy]

  def new
  end

  def create
    unless user = User.find_by_login(params[:login])
      flash[:error] = "Incorrect username or password"
      return render("new")
    end

    unless user.authenticate(params[:password])
      flash[:error] = "Incorrect username or password"
      return render("new")
    end

    login_as(user)
    redirect_to root_path
  end

  def destroy
    reset_session
    @current_user = nil
    flash[:notice] = "Logged out"
    redirect_to root_path
  end
end
