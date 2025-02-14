# Redmine Web Forms - A Redmine Plugin
# Copyright (C) 2022  Frederico Camara
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WebformsController < ApplicationController
  skip_before_action :check_if_login_required, :only => [:show, :new_issue]
  before_action :require_admin, :except => [:show, :new_issue]

  helper :custom_fields
  helper :issues # Fix RedmineUp expecting new issues only from Issue Controller

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
    errors = @webform.validate_webform_errors(user=nil).join(" ")
    flash.now[:error] = errors if errors.present?
    warnings = webform_custom_field_warnings.join(" ")
    flash.now[:warning] = warnings if warnings.present?
  end

  def create
    @webform = Webform.new
    update_webform_from_params

    if @webform.save
      flash[:notice] = l(:notice_successful_create)
      errors = @webform.validate_webform_errors(user=nil).join(" ")
      flash[:error] = errors if errors.present?
      warnings = webform_custom_field_warnings.join(" ")
      flash[:warning] = warnings if warnings.present?
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
        errors = @webform.validate_webform_errors(user=nil).join(" ")
        flash[:error] = errors if errors.present?
        warnings = webform_custom_field_warnings.join(" ")
        flash[:warning] = warnings if warnings.present?
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
    @user = @webform.use_user_id.present? ? User.find(@webform.use_user_id) : require_login && User.current || return
    @priorities = IssuePriority.active
    @webform_questions = map_non_cf_answers

    @issue = Issue.new(project: @webform.project, tracker:@webform.tracker, author:@user)
    # Proceed if there are no invalid custom fields
    ifs = (
      @webform.webform_custom_field_values.map(&:custom_field_id) +
      @webform.webform_questions.map(&:custom_field_id) -
      @issue.custom_field_values.map(&:custom_field_id)
    ).select{|i| i.to_i > 0}

    return true if @webform.validate_webform && ifs.empty?

    errors = [l(:error_webform_in_maintenance)]

    if @user.admin?
      errors += @webform.validate_webform_errors
      errors += [l(:error_webform_invalid_fs, :ifs => ifs.join(', '))] if ifs.present?
    end

    render_error :message => errors.join(', '), :status => 403
    return false
  end

  def destroy
    find_webform.destroy
    redirect_to webforms_path
  end

  def new_issue
    @webform = find_webform_by_identifier
    @user = @webform.use_user_id.present? ? User.find(@webform.use_user_id) : require_login && User.current || return
    @priorities = IssuePriority.active
    if @webform.validate_webform
      # Add user to group if not already
      if @webform.group.present?
        @user.group_ids+=[@webform.group_id] unless @webform.group.users.include?(@user)
      end

      # Add user to role in project if not already
      if @webform.role.present?
        unless User.find(@user.id).roles_for_project(@webform.project).include?(@webform.role)
          Member.create_principal_memberships(@user, :project_ids => [@webform.project_id], :role_ids => [@webform.role_id])
        end
      end

      build_new_issue_from_params

      unless @issue.allowed_target_projects(@user, @webform.project).present?
        raise ::Unauthorized
      end

      if validate_required_webform_questions && @issue.save
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
        redirect_back_or_default issue_path(@issue)
        return
      else
        @webform_questions = map_non_cf_answers
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

    @priorities = IssuePriority.active
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
      [ l(:field_fixed_version), -5],
      [ l(:field_priority), -6],
      [ l(:field_parent_issue), -7],
      [ l(:field_start_date), -8],
      [ l(:field_due_date), -9],
      [ l(:field_done_ratio), -10]
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
    @priorities = IssuePriority.active
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
      @issue.priority_id = cf.value                                    if cf.custom_field_id == -6
      @issue.parent_issue_id = cf.value                                if cf.custom_field_id == -7
      @issue.start_date = cf.value                                     if cf.custom_field_id == -8
      @issue.due_date = cf.value                                       if cf.custom_field_id == -9
      @issue.done_ratio = cf.value                                     if cf.custom_field_id == -10
      @issue.custom_field_values = {"#{cf.custom_field_id}": cf.value} if cf.custom_field.present?
    end

    param_attrs = (params[:issue] || {}).deep_dup

    attrs = {"custom_field_values"=>{}}
    @webform.webform_questions.map{|x| x.custom_field_id.to_i}.select{|x| x != 0}.each do |x|
      case x
      when -1; attrs["assigned_to_id"]=param_attrs["assigned_to_id"]
      when -2; attrs["category_id"]=param_attrs["category_id"]
      when -3; attrs["description"]=param_attrs["description"]
      when -4; attrs["subject"]=param_attrs["subject"]
      when -5; attrs["fixed_version_id"]=param_attrs["fixed_version_id"]
      when -6; attrs["priority_id"]=param_attrs["priority_id"]
      when -7; attrs["parent_issue_id"]=param_attrs["parent_issue_id"]
      when -8; attrs["start_date"]=param_attrs["start_date"]
      when -9; attrs["due_date"]=param_attrs["due_date"]
      when -10; attrs["done_ratio"]=param_attrs["done_ratio"]
      else;    attrs["custom_field_values"][x.to_s]=param_attrs["custom_field_values"][x.to_s]
      end
    end
    if @webform.allow_attachments
      @issue.save_attachments(params[:attachments]&.except("dummy") || (params[:issue] && params[:issue][:uploads]))
    end
    @issue.safe_attributes = attrs
  end

  def update_webform_from_params
    param_attrs = (params[:webform] || {}).deep_dup
    @webform.safe_attributes = param_attrs

    param_attrs = (params[:webform_questions] || {}).deep_dup
    @webform.webform_questions=[]
    param_attrs.values.each do |q|
      @webform.webform_questions.new.safe_attributes = q
    end

    param_attrs = (params[:webform_custom_field_values] || {}).deep_dup
    @webform.webform_custom_field_values=[]
    param_attrs.values.each do |p|
      @webform.webform_custom_field_values.new.safe_attributes = p
    end
  end

  def webform_custom_field_warnings
    if @webform.project.present? && @webform.tracker.present? && @webform.issue_status.present?
      warnings = @webform.validate_webform_fs_errors
    else
      warnings = [l(:notice_skip_custom_field_verification)]
    end
  end

  def validate_required_webform_questions
    @webform.webform_questions.where(required: true).each do |q|
      param_attrs_w = (params[:issue] || {}).deep_dup
      param_attrs_q = (params[:webform_questions] || {}).deep_dup
      if q.custom_field_id.present?
        case q.custom_field_id
        when -1; webform_question_error(q.description.presence || l(:field_assigned_to)) unless param_attrs_w["assigned_to_id"].present?
        when -2; webform_question_error(q.description.presence || l(:field_category)) unless param_attrs_w["category_id"].present?
        when -3; webform_question_error(q.description.presence || l(:field_description)) unless param_attrs_w["description"].present?
        when -4; webform_question_error(q.description.presence || l(:field_subject)) unless param_attrs_w["subject"].present?
        when -5; webform_question_error(q.description.presence || l(:field_fixed_version)) unless param_attrs_w["fixed_version_id"].present?
        when -6; webform_question_error(q.description.presence || l(:field_priority)) unless param_attrs_w["priority_id"].present?
        when -7; webform_question_error(q.description.presence || l(:field_parent_issue)) unless param_attrs_w["parent_issue_id"].present?
        when -8; webform_question_error(q.description.presence || l(:field_start_date)) unless param_attrs_w["start_date"].present?
        when -9; webform_question_error(q.description.presence || l(:field_due_date)) unless param_attrs_w["due_date"].present?
        when -10; webform_question_error(q.description.presence || l(:field_done_ratio)) unless param_attrs_w["done_ratio"].present?
        else;    webform_question_error(q.description.presence || q.custom_field.name) unless param_attrs_w["custom_field_values"].present? && param_attrs_w["custom_field_values"][q.custom_field_id.to_s].present?
        end
      else
        if q.possible_values.any?
          webform_question_error(q.description) unless q.possible_values.include?(param_attrs_q[q.id.to_s])
        else
          webform_question_error(q.description) if param_attrs_q[q.id.to_s].empty?
        end
      end
    end
    if @webform.errors.any?
      @issue.valid?
      return false
    else
      return true
    end
  end

  def map_non_cf_answers
    param_attrs_q = (params[:webform_questions] || {}).deep_dup
    @webform.webform_questions.select{|q| ! q.custom_field_id.present?}.map{|q| [q.id, param_attrs_q[q.id.to_s] || '']}.to_h
  end

  def webform_question_error(q)
    @webform.errors.add :base, ActionController::Base.helpers.strip_tags(Redmine::WikiFormatting.to_html('textile',q)) + " " + ::I18n.t('activerecord.errors.messages.blank')
  end
end
