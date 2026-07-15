class BlogController < ApplicationController
  def index
    authorize Post
    @posts = Post.publicados
  end

  def show
    @post = Post.find_by!(slug: params[:id])
    authorize @post
  end
end
