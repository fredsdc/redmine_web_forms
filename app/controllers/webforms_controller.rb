class WebformsController < ApplicationController
  before_action :require_login
  before_action :require_admin, :except => :show

  def show
    @webform = find_webform
    if @webform.validate_webform
      @issue = Issue.new(project: @webform.project, tracker:@webform.tracker)
    else
      render_error :message => l(:error_webform_in_maintenance), :status => 403
      return false
    end
  end

  def new_issue
    webform = find_webform
    Rails.logger.warn('FWH: New Issue')
  end

  private

  def find_webform
    Webform.find(params[:id])
  end
end
