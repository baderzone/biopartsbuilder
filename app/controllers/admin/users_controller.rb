class Admin::UsersController < ApplicationController
  authorize_resource :class => :admin
  layout 'admin'	
	
	def index
    @users = User.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def edit
    @user = User.find(params[:id])
  end
  
  def update
    @user = User.find(params[:id])
    
    if @user.update_attributes(params[:user])
      redirect_to admin_users_path, :notice => "Information updated correctly."
    else
      render :edit
    end
    
  end
  
end
