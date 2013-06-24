class OrdersController < ApplicationController

  def index
    @orders = current_user.orders.paginate(:page => params[:page], :per_page => 10).order("id DESC")
  end

  def show
    @order = Order.find(params[:id])
    @designs = @order.designs.paginate(:page => params[:page], :per_page => 10).order("id DESC")
    @construct_num = 0
    @construct_bp = 0
    @designs.each do |d|
      @construct_num += d.constructs.size
      d.constructs.each {|c| @construct_bp += c.seq.size}
    end
  end

  def new
    @order = Order.new
    @designs = Design.all
  end

  def create
    if params[:name].nil? || params[:order][:vendor_id].nil? || params[:design_id].nil?
      redirect_to new_order_path, :alert => "Please input order name, select one vendor, and select at least one design!"
    else
      
      @order = Order.new(:name => params[:name], :user_id => current_user.id, :vendor_id => params[:order][:vendor_id], :design_ids => params[:design_id])
      if @order.save      
      
        @job = Job.create(:job_type_id => JobType.find_by_name('order').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
        worker_params = {:order_id => @order.id, :designs => params[:design_id], :job_id => @job.id, :vendor_id => @order.vendor_id}
        OrderWorker.perform_async(worker_params)
        redirect_to job_path(@job.id), :notice => "Order submitted!"
      
      else
        render :new
      end 
    end
  end

  def get_zip_file
    result_path = "#{PARTSBUILDER_CONFIG['program']['order_path']}/#{params[:id]}"
    filename = "#{result_path}/order#{params[:id]}.zip"
    send_file filename, :type => 'archive/zip', :disposition => 'inline'
  end

end
