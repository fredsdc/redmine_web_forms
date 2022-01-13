class WebformsController < ApplicationController
  before_action :require_login
  before_action :require_admin, :except => :show

  before_action :find_webform, :only => [:show, :edit, :update]

  def new_issue
    Rails.logger.warn('FWH: New Issue')
  end

  private

  def find_webform
    @webform = Webform.find(params[:id])
    @issue = Issue.new(project: @webform.project, tracker:@webform.tracker)
  end
end
