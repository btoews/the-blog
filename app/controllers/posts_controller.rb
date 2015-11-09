class PostsController < ApplicationController
  before_filter :admin_only,         only: [:new, :create, :edit, :update]
  before_filter :authenticated_only, only: [:like, :dislike]

  def index
    @posts = Post.all
  end

  def search
    @posts = Post.search(params[:q])
  end

  def show
    @already_voted = logged_in? && this_post.votes.where(user: current_user).any?
  end

  def new
    @this_post = Post.new
  end

  def create
    @this_post = Post.new post_params
    if this_post.save
      flash.now[:error] = this_post.errors.full_messages.to_sentence
      render :new
    else
      redirect_to post_path(this_post)
    end
  end

  def edit
  end

  def update
    if this_post.update_attributes post_params
      redirect_to post_path(this_post)
    else
      flash[:error] = this_post.errors.full_messages.to_sentence
      redirect_to edit_post_path(this_post)
    end
  end

  def like
    vote +1
  end

  def dislike
    vote -1
  end

  private

  def vote(value)
    record = current_user.votes.new(post: this_post, value: value)
    if record.save
      render json: { error: "", votes: this_post.score, the_flag: ENV['THE_FLAG'] }
    else
      render json: { error: record.errors.full_messages.to_sentence, votes: this_post.score }
    end
  end

  def post_params
    params.require(:post).permit(:name, :body)
  end

  def this_post
    return @this_post if defined? @this_post
    @this_post = Post.find_by_id(params[:id].to_i)
  end
  helper_method :this_post
end
