class GreatsController < ApplicationController
  def create
    post = Post.find(params[:post_id])
    current_user.great(post)
    redirect_back fallback_location: root_path, warning: 'いいねしました'
  end

  def destroy
    post = current_user.greats.find(params[:id]).post
    current_user.ungreat(post)
    redirect_back fallback_location: root_path, warning: 'いいねを解除しました'
  end
end
