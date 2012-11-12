class SequencesController < ApplicationController
  def index
    @sequences = Sequence.all
  end

  def show
    @sequence = Sequence.find(params[:id])
  end

  def new
    @sequence = Sequence.new
  end

  def create
    if params[:sequence].empty?
      render :new
    else
      params[:sequence]['accession'].split("\r\n").each do |entry|
        entry.strip!
        if Sequence.where("accession = ?", entry).empty?
          @sequence = Sequence.new(:accession => entry)
          if @sequence.save
            #Resque.enqueue(NewPart, entry)
          end
        end
      end
      redirect_to parts_path, :notice => "Parts submitted correctly!"
    end
  end

end
