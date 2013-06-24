class ProtocolsController < ApplicationController
  def index
    @protocols = current_user.lab.protocols.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @protocol = Protocol.find(params[:id])
  end

end
