class Admin::PostsController < ApplicationController
  before_action :cargar_post, only: %i[ edit update destroy publicar ]

  def index
    authorize Post, :admin_index?
    @posts = Post.order(created_at: :desc)
  end

  def new
    @post = Post.new
    authorize @post
  end

  def create
    @post = Post.new(post_params)
    @post.autor = Current.user
    authorize @post

    if @post.save
      redirect_to admin_posts_path, notice: "Post creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to admin_posts_path, notice: "Post actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_posts_path, notice: "Post eliminado."
  end

  def publicar
    @post.publicar!
    redirect_to admin_posts_path, notice: "Post publicado."
  end

  private
    def cargar_post
      @post = Post.find(params[:id])
      authorize @post
    end

    def post_params
      params.expect(post: [ :titulo, :slug, :contenido ])
    end
end
