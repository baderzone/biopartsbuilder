class Admin::ProtocolsController < ApplicationController
  authorize_resource :class => :admin
	layout 'admin'

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
    if params[:protocol]['forbid_enzymes'].include?("\r\n")
      params[:protocol]['forbid_enzymes'] = params[:protocol]['forbid_enzymes'].split("\r\n").join(':')
    end
    if params[:protocol]['check_enzymes'].include?("\r\n")
      params[:protocol]['check_enzymes'] = params[:protocol]['check_enzymes'].split("\r\n").join(':')
    end
    @protocol = Protocol.new(params[:protocol])

    if @protocol.save
      redirect_to admin_protocol_path(@protocol), notice: 'New protocol created!'
    else
      render :new
    end
  end

  def edit
    @protocol = Protocol.find(params[:id])
  end

  def update
    @protocol = Protocol.find(params[:id])
    if params[:protocol]['overlap'].include?("\r\n")
      params[:protocol]['overlap'] = params[:protocol]['overlap'].split("\r\n").join(',').upcase
    end
    if params[:protocol]['forbid_enzymes'].include?("\r\n")
      params[:protocol]['forbid_enzymes'] = params[:protocol]['forbid_enzymes'].split("\r\n").join(':')
    end
    if params[:protocol]['check_enzymes'].include?("\r\n")
      params[:protocol]['check_enzymes'] = params[:protocol]['check_enzymes'].split("\r\n").join(':')
    end
    if @protocol.update_attributes(params[:protocol])
      redirect_to admin_protocol_path(@protocol), :notice => "Protocol updated"
    else
      render :edit, :id => @protocol, :flash => {:error => "Protocol update failed."}
    end
  end

end
