class ConstructsController < ApplicationController
  # GET /constructs
  # GET /constructs.json
  def index
    @constructs = Construct.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @constructs }
    end
  end

  # GET /constructs/1
  # GET /constructs/1.json
  def show
    @construct = Construct.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @construct }
    end
  end

  # GET /constructs/new
  # GET /constructs/new.json
  def new
    @construct = Construct.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @construct }
    end
  end

  # GET /constructs/1/edit
  def edit
    @construct = Construct.find(params[:id])
  end

  # POST /constructs
  # POST /constructs.json
  def create
    @construct = Construct.new(params[:construct])

    respond_to do |format|
      if @construct.save
        format.html { redirect_to @construct, notice: 'Construct was successfully created.' }
        format.json { render json: @construct, status: :created, location: @construct }
      else
        format.html { render action: "new" }
        format.json { render json: @construct.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /constructs/1
  # PUT /constructs/1.json
  def update
    @construct = Construct.find(params[:id])

    respond_to do |format|
      if @construct.update_attributes(params[:construct])
        format.html { redirect_to @construct, notice: 'Construct was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @construct.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /constructs/1
  # DELETE /constructs/1.json
  def destroy
    @construct = Construct.find(params[:id])
    @construct.destroy

    respond_to do |format|
      format.html { redirect_to constructs_url }
      format.json { head :no_content }
    end
  end
end
