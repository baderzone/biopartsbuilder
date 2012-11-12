class UsersController < ApplicationController
  def index
    @user = current_user
  end

  def edit
    @user = User.find(current_user.id)
  end
  
  def update
    @user = User.find(current_user.id)
    
    if @user.update_attributes(params[:user])
      redirect_to users_path, :notice => "Information updated correctly."
    else
      render :edit
    end
    
  end
  
end
