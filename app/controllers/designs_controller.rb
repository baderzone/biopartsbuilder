class DesignsController < ApplicationController

  def index
    @designs = Design.all
  end

  def show
    begin
      @design = Design.find(params[:id])
    rescue  
      redirect_to designs_path, :alert => "Design unfinished! Please COME BACK 10 minutes later"
    end

  end

  def new
    @parts = Part.all
    @protocols = Protocol.all
    @design = Design.new
  end

  def create
    if params[:design].nil? || params[:design][:protocol_id].nil? || params[:design][:part_id].nil?
      redirect_to new_design_path, :alert => "at least one protocol and one part should be selected"
    else
      params[:design][:part_id].each do |part_id|
        if Design.where("part_id = ? AND protocol_id = ?", part_id, params[:design][:protocol_id]).empty?
          @design = Design.new(:part_id => part_id, :protocol_id => params[:design][:protocol_id])
          if @design.save
            Resque.enqueue(DesignPart, @design.id)
          end
        end
      end
      redirect_to designs_path, :notice => "Designs submitted correctly!"
    end
  end

end
