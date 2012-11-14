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

end
