class WebformsController < ApplicationController
  before_action :require_login
  before_action :require_admin, :except => [:show, :new_issue]

  def index
    @webforms = Webform.all
  end

  def new
    @webform = Webform.new
    default_parameters
  end

  def show
    @webform = find_webform
    if @webform.validate_webform
      @issue = Issue.new(project: @webform.project, tracker:@webform.tracker)
    else
      render_error :message => l(:error_webform_in_maintenance), :status => 403
      return false
    end
  end

  def destroy
    Webform.find(params[:id]).destroy
    redirect_to webforms_path
  end

  def new_issue
    @webform = find_webform
    @user = User.current
    if @webform.validate_webform
      # Add user to group if not already
      if @webform.group.present?
        @user.group_ids+=[@webform.group_id] unless @webform.group.users.include?(@user)
      end

      # Add user to role in project if not already
      if @webform.role.present?
        unless @user.roles_for_project(@webform.project).include?(@webform.role)
          if @user.membership(@webform.project).nil?
            Member.create(user: @user, project: @webform.project, roles: [@webform.role])
          else
            @user.membership(@webform.project).roles+=[@webform.role]
          end
        end
      end

      build_new_issue_from_params

      unless @issue.allowed_target_projects(@user, @webform.project).present?
        raise ::Unauthorized
      end

      if @issue.save
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
        redirect_back_or_default issue_path(@issue)
        return
      else
        render :action => 'show'
      end
    end
  end

  def update_selects
    default_parameters
    update_webform_from_params

    if @webform.project.present? && @webform.project.active?
      @trackers =  @webform.project.trackers.order(:name).map{|t| [t.name, t.id]}
      if @trackers.pluck(1).include?(@webform.tracker_id)
        @statuses = IssueStatus.find(
          WorkflowTransition.where(
            old_status_id: 0,
            tracker_id: @webform.tracker_id,
            workspace_id: @webform.project.workspace_id
          ).pluck(:new_status_id) |
          [ @webform.tracker.default_status_id ]
        ).map{|t| [t.name, t.id]}
      end
    end

    respond_to do |format|
      format.js
    end
  end

  private

  def default_parameters
    @projects = Project.all.active
    @trackers = Tracker.order(:name).map{|t| [t.name, t.id]}
    @statuses = IssueStatus.find(
      WorkflowTransition.where(old_status_id: 0).pluck(:new_status_id) |
      Tracker.all.map{|t| t.default_status_id}
    ).map{|t| [t.name, t.id]}
    @roles = Role.select{|r| r.has_permission?(:add_issues)}.pluck(:name, :id)
    @groups = Group.all.pluck(:lastname, :id)
  end

  def build_new_issue_from_params
    @issue = Issue.new
    @issue.project = @webform.project
    @issue.tracker = @webform.tracker
    @issue.status = @webform.issue_status
    @issue.author ||= @user
    @issue.start_date ||= @user.today if Setting.default_issue_start_date_to_creation_date?

    param_attrs = (params[:issue] || {}).deep_dup
    attrs = param_attrs.slice("custom_field_values")
    attrs["assigned_to_id"]=param_attrs["assigned_to_id"] if @webform.questions.pluck(:custom_field_id).include?(-1)
    attrs["category_id"]=param_attrs["category_id"] if @webform.questions.pluck(:custom_field_id).include?(-2)
    attrs["description"]=param_attrs["description"] if @webform.questions.pluck(:custom_field_id).include?(-3)
    attrs["subject"]=param_attrs["subject"] if @webform.questions.pluck(:custom_field_id).include?(-4)
    attrs["fixed_version_id"]=param_attrs["fixed_version_id"] if @webform.questions.pluck(:custom_field_id).include?(-4)
    @issue.safe_attributes = attrs

    @webform.webform_custom_field_values.each do |cf|
      @issue.assigned_to_id = cf.value                                 if cf.custom_field_id == -1
      @issue.category_id = cf.value                                    if cf.custom_field_id == -2
      @issue.description = cf.value                                    if cf.custom_field_id == -3
      @issue.subject = cf.value                                        if cf.custom_field_id == -4
      @issue.fixed_version_id = cf.value                               if cf.custom_field_id == -5
      @issue.custom_field_values = {"#{cf.custom_field_id}": cf.value} if cf.custom_field.present?
    end
  end

  def update_webform_from_params
    @webform = Webform.new
    param_attrs = (params[:webform] || {}).deep_dup
    @webform.safe_attributes = param_attrs
  end

  def find_webform
    Webform.find(params[:id])
  end
end
