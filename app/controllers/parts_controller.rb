class PartsController < ApplicationController
  def index
    @parts = Part.all
  end

  def show
    @part = Part.find(params[:id])
  end

  def new
    @part = Part.new
  end

  def create
    if params[:accession].empty?
      render :new
    else
      params[:accession].split("\r\n").each do |entry|
        entry.strip!
        if Sequence.where("accession = ?", entry).empty?
          Resque.enqueue(NewPart, entry)
        end 
      end 
      redirect_to parts_path, :notice => "Parts submitted correctly!"
    end 
  end

end
