class LabsController < ApplicationController
  skip_before_filter :is_valid_session?
  
  def index
    @labs = Lab.paginate(:page => params[:page], :per_page => 10).order('name')
  end

  def new
    @lab = Lab.new
  end  
  
  def create
    @lab = Lab.new
    if params[:lab][:name].blank? || params[:user_name].blank? || params[:email].blank? || params[:email].include?('@gmail.com')
    @lab = Lab.create(params[:lab])
    @lab.users.create(:fullname => params[:user_name], :email => params[:email], :group_id => 1, :provider => 'google')
    redirect_to root_url, :notice => 'Your group is created!'
    else
      flash[:error] = 'Lab name, you fullname and email address cannot be empty. And only gmail account is acceptable'
      render :new
    end
  end
  
end
