class FlowTasksController < ApplicationController
  before_filter :load_flow_task, :only => [:show, :destroy, :run]

  def index
    @flow_tasks = FlowTask.order("id desc").paginate(:page => params[:page])
  end

  def show
  end

  def new
    klass = params[:type].camlize.constantize rescue FlowTask
    @flow_task = klass.new
  end

  def create
    class_name = params.keys.detect{|k| k =~ /flow_task/}
    klass = class_name.camelize.constantize rescue FlowTask
    @flow_task = klass.new(params[class_name])
    @flow_task.user = current_user
    if @flow_task.save
      flash[:notice] = "Flow task created"
      redirect_to run_flow_task_path(@flow_task)
    else
      render :new
    end
  end

  def run
    # Get the flow task id and type frmo params[:id], a composite of id and type
    flow_task_id, flow_task_type = params[:id].split /-/
    # Convert flow task type from string to Sidekiq job class
    flow_task_job = "FlowTaskJob::#{flow_task_type.camelize}".constantize
    # Set @job from params[:job]
    @job = params[:job]
    # If @job has content, check on the status of the flow task related to the job
    if @job
      @flow_task = FlowTask.find(flow_task_id.to_i)
      # Check whether the Sidekiq flow task job is still alive
      if Sidekiq::Status::failed? @job
        @flow_task.update_attribute(:error_msg, "The flow task run into system error, please contact Admin.")
      end
      @status = @flow_task.status
      @error_msg = @flow_task.error_msg if @status == "error"
      @tries = params[:tries].to_i
    # Else start the Sidekiq job for the flow task
    else
      @job = flow_task_job.perform_async(flow_task_id)
      @status = "start"
      @tries = 1
    end
  end

  def destroy
    @flow_task.destroy
    flash[:notice] = "Flow task destroyed"
    redirect_to flow_tasks_path
  end

  private

  def load_flow_task
    return true if @flow_task = FlowTask.find(params[:id].to_i)
    flash[:error] = "That task doesn't exist"
    redirect_to flow_tasks_path
    false
  end

end
