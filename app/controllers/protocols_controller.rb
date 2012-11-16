class ProtocolsController < ApplicationController
  def index
    @protocols = Protocol.all
  end

  def show
    @protocol = Protocol.find(params[:id])
  end

  def new
    @protocol = Protocol.new
  end

  def create
    if params[:protocol]['overlap'].include?("\r\n")
      params[:protocol]['overlap'] = params[:protocol]['overlap'].split("\r\n").join(',').upcase
    end
    if params[:protocol]['rs_enz'].include?("\r\n")
      params[:protocol]['rs_enz'] = params[:protocol]['rs_enz'].split("\r\n").join(':')
    end
    @protocol = Protocol.new(params[:protocol])

    if @protocol.save
      redirect_to @protocol, notice: 'Protocol was successfully created.'
    else
      render :new
    end
  end

end
