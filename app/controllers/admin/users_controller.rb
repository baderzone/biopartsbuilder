class Admin::UsersController < ApplicationController
  authorize_resource :class => :admin
  layout 'admin'	

  def index
    @users = current_user.lab.users.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.email.include?('@gmail.com')
      @user.lab = current_user.lab

      if @user.save
        return redirect_to admin_users_path, notice: 'New member added!'
      else  
        flash[:error] = 'Something went wrong.  Please try again.'
        return render :new
      end       
    else
      flash[:error] = 'Only gmail account is acceptable'
      render :new
    end
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

  def destroy
    @user = User.find(params[:id])
    if @user.destroy
      redirect_to admin_users_path, :notice => "User Deleted!"
    else
      flash[:error] = 'Something went wrong.  Please try again!'
    end
  end

end
