class Admin::ProtocolsController < ApplicationController
  authorize_resource :class => :admin
  layout 'admin'

  def index
    @protocols = current_user.lab.protocols.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @protocol = Protocol.find(params[:id])
  end

  def new
    @protocol = Protocol.new
  end

  def create
    params[:protocol]['forbid_enzymes'].strip!
    ens = []
    params[:protocol]['forbid_enzymes'].split("\r\n").each do |e|
      enzyme = Enzyme.find(:first, :conditions => ["BINARY name = ?", e.strip])
      if enzyme.nil?
        return redirect_to new_admin_protocol_path, :flash => {:error => "Restriction enzyme name '#{e}' is not correct. You must respect the usual naming convention with the upper case letters and Latin numbering"}
      else
        ens << e.strip
      end
    end
    params[:protocol]['forbid_enzymes'] = ens.join(':')

    params[:protocol]['check_enzymes'].strip!
    ens = []
    params[:protocol]['check_enzymes'].split("\r\n").each do |e|
      enzyme = Enzyme.find(:first, :conditions => ["BINARY name = ?", e.strip])
      if enzyme.nil?
        return redirect_to new_admin_protocol_path, :flash => {:error => "Restriction enzyme name '#{e}' is not correct. You must respect the usual naming convention with the upper case letters and Latin numbering"}
      else
        ens << e.strip
      end
    end
    params[:protocol]['check_enzymes'] = ens.join(':')

    if params[:protocol]['overlap'].include?("\r\n")
      params[:protocol]['overlap'] = params[:protocol]['overlap'].split("\r\n").join(',').upcase
    end
    @protocol = Protocol.new(params[:protocol])
    @protocol.lab = current_user.lab

    if @protocol.save
      return redirect_to admin_protocol_path(@protocol), notice: 'New protocol created!'
    else
      return redirect_to new_admin_protocol_path, :flash => {:error => 'Name cannot be empty, please try again'}
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
      designs = Design.find_all_by_protocol_id(@protocol.id)
      if !designs.nil?
        part_ids = Array.new
        designs.each do |d|
          part_ids << d.part_id
        end
        worker_params = {:protocol_id => @protocol.id, :part_id => part_ids, :user_id => current_user.id}
        UpdateDesign.perform_async(worker_params)
      end
      redirect_to admin_protocol_path(@protocol), :notice => "Protocol updated"
    else
      render :edit, :id => @protocol, :flash => {:error => "Protocol update failed."}
    end
  end

end
