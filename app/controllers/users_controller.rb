class UsersController < ApplicationController
  before_filter :invite_required, only: [:new, :create]
  before_filter :anonymous_only,  only: [:new, :create]
  before_filter :admin_only,      only: [:invites]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save && invite.redeem!
      login_as(@user)
      flash[:notice] = "You are now logged in as #{@user.login}"
      redirect_to "/"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence
      render "new"
    end
  end

  def invites
    urls = 10.times.map { new_user_url(invite: Invite.generate(current_user)) }
    render plain: urls.join("\n")
  end

  private

  def invite_required
    access_denied unless invite
    access_denied unless invite.valid?
  end

  def invite
    return @invite if defined? @invite
    @invite = Invite.from_token params[:invite]
  end
  helper_method :invite

  def user_params
    params.require(:user).permit(:login, :password, :password_confirmation)
  end
end
