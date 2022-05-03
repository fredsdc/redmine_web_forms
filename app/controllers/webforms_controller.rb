class WebformsController < ApplicationController
  before_action :require_login
  before_action :require_admin, :except => [:show, :new_issue]

  helper :custom_fields

  def index
    @webforms = Webform.all
  end

  def new
    @webform = Webform.new
    default_parameters
  end

  def edit
    @webform = find_webform
    default_parameters
    get_variables_from_webform
  end

  def create
    @webform = Webform.new
    update_webform_from_params

    if @webform.save
      flash[:notice] = l(:notice_successful_create)
      webform_custom_field_warnings
      respond_to do |format|
        format.html { redirect_back_or_default webforms_path }
      end
    else
      default_parameters
      get_variables_from_webform

      respond_to do |format|
        format.html { render :action => 'new' }
      end
    end
  end

  def update
    Webform.transaction do
      @webform = find_webform
      update_webform_from_params

      if @webform.save
        flash[:notice] = l(:notice_successful_update)
        webform_custom_field_warnings
        respond_to do |format|
          format.html { redirect_back_or_default webforms_path }
        end
      else
        default_parameters
        get_variables_from_webform

        respond_to do |format|
          format.html { render :action => 'edit' }
        end

        raise ActiveRecord::Rollback
      end
    end
  end

  def show
    @webform = find_webform_by_identifier
    if @webform.validate_webform
      @issue = Issue.new(project: @webform.project, tracker:@webform.tracker)
      # Proceed if there are no invalid custom fields
      return true if (
        @webform.webform_custom_field_values.map(&:custom_field_id) +
        @webform.questions.map(&:custom_field_id) -
        @issue.custom_field_values.map(&:custom_field_id)
      ).select{|i| i.to_i > 0}.empty?
    end

    render_error :message => l(:error_webform_in_maintenance), :status => 403
    return false
  end

  def destroy
    find_webform.destroy
    redirect_to webforms_path
  end

  def new_issue
    @webform = find_webform_by_identifier
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
    @webform = Webform.new
    update_webform_from_params
    get_variables_from_webform

    respond_to do |format|
      format.js
    end
  end

  def update_custom_field
    @webform = Webform.new
    update_webform_from_params
    get_variables_from_webform

    @wcfv = @webform.webform_custom_field_values.first
    @n = params[:n]

    respond_to do |format|
      format.js
    end
  end

  private

  def find_webform
    Webform.find(params[:id])
  end

  def find_webform_by_identifier
    Webform.where(identifier: params[:id]).first
  end

  def get_variables_from_webform
    if @webform.project.present? && @webform.project.active?
      @trackers =  @webform.project.trackers.reorder(:name).map{|t| [t.name, t.id]}
      @custom_fields = issue_core_fields
      if @trackers.map{|k,v| v}.include?(@webform.tracker_id)
        @statuses = IssueStatus.sorted.find(
          WorkflowTransition.where(
            old_status_id: 0,
            tracker_id: @webform.tracker_id
          ).pluck(:new_status_id) |
          [ @webform.tracker.default_status_id ]
        ).map{|t| [t.name, t.id]}
        @custom_fields += Issue.new(project_id: @webform.project_id, tracker_id: @webform.tracker_id).editable_custom_fields.pluck(:name, :id)
      else
        @custom_fields += @webform.project.trackers.map{|t| Issue.new(project_id: @webform.project_id, tracker_id: t.id).editable_custom_fields}.flatten.uniq.sort.pluck(:name, :id)
      end
    else
      @custom_fields = issue_core_fields + CustomField.order(:name).pluck(:name, :id)
    end
  end

  def issue_core_fields
    [
      [ l(:field_assigned_to), -1],
      [ l(:field_category), -2],
      [ l(:field_description), -3],
      [ l(:field_subject), -4],
      [ l(:field_fixed_version), -5]
    ]
  end

  def default_parameters
    @projects = Project.all.active
    @trackers = Tracker.order(:name).map{|t| [t.name, t.id]}
    @statuses = IssueStatus.sorted.find(
      WorkflowTransition.where(old_status_id: 0).pluck(:new_status_id) |
      Tracker.all.map{|t| t.default_status_id}
    ).map{|t| [t.name, t.id]}
    @roles = Role.sorted.select{|r| r.has_permission?(:add_issues)}.pluck(:name, :id)
    @groups = Group.sorted.pluck(:lastname, :id)
    @custom_fields = issue_core_fields + CustomField.order(:name).pluck(:name, :id)
  end

  def build_new_issue_from_params
    @issue = Issue.new
    @issue.project = @webform.project
    @issue.tracker = @webform.tracker
    @issue.status = @webform.issue_status
    @issue.author ||= @user
    @issue.start_date ||= @user.today if Setting.default_issue_start_date_to_creation_date?

    @webform.webform_custom_field_values.each do |cf|
      @issue.assigned_to_id = cf.value                                 if cf.custom_field_id == -1
      @issue.category_id = cf.value                                    if cf.custom_field_id == -2
      @issue.description = cf.value                                    if cf.custom_field_id == -3
      @issue.subject = cf.value                                        if cf.custom_field_id == -4
      @issue.fixed_version_id = cf.value                               if cf.custom_field_id == -5
      @issue.custom_field_values = {"#{cf.custom_field_id}": cf.value} if cf.custom_field.present?
    end

    param_attrs = (params[:issue] || {}).deep_dup

    attrs = {"custom_field_values"=>{}}
    @webform.questions.map{|x| x.custom_field_id.to_i}.select{|x| x != 0}.each do |x|
      case x
      when -1; attrs["assigned_to_id"]=param_attrs["assigned_to_id"]
      when -2; attrs["category_id"]=param_attrs["category_id"]
      when -3; attrs["description"]=param_attrs["description"]
      when -4; attrs["subject"]=param_attrs["subject"]
      when -5; attrs["fixed_version_id"]=param_attrs["fixed_version_id"]
      else;    attrs["custom_field_values"][x.to_s]=param_attrs["custom_field_values"][x.to_s]
      end
    end
    @issue.safe_attributes = attrs
  end

  def update_webform_from_params
    param_attrs = (params[:webform] || {}).deep_dup
    @webform.safe_attributes = param_attrs

    param_attrs = (params[:questions] || {}).deep_dup
    @webform.questions=[]
    param_attrs.values.each do |q|
      @webform.questions.new.safe_attributes = q
    end

    param_attrs = (params[:webform_custom_field_values] || {}).deep_dup
    @webform.webform_custom_field_values=[]
    param_attrs.values.each do |p|
      @webform.webform_custom_field_values.new.safe_attributes = p
    end
  end

  def webform_custom_field_warnings
    warnings=[]
    if @webform.project.present? && @webform.tracker.present? && @webform.issue_status.present?
      roles = (Member.where(user_id: @webform.group_id, project_id: @webform.project_id).map{|m| m.roles.ids}.flatten |
        [@webform.role_id] - [nil]).presence || [1]

      @webform.questions.select{|x| x.custom_field.present?}.map{|x| x.custom_field}.each do |cf|
        unless cf.visible? || (roles & cf.roles.ids - WorkflowPermission.where(tracker_id: @webform.tracker_id,
               old_status_id: @webform.issue_status_id, field_name: cf.id.to_s,
               rule: "readonly").pluck(:role_id)).any?
          warnings += [l(:notice_no_role_for_custom_field, :name => cf.name)]
        end
      end
    else
      warnings += [l(:notice_skip_custom_field_verification)]
    end
    if warnings.present?
      flash[:warning] = flash[:warning].present? ? ([ flash[:warning] ] + warnings).join(" ") : warnings.join(" ")
    end
  end
end
