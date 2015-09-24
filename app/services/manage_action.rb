class ManageAction
  def initialize(params)
    @params = params
  end

  def create
    Action.find_or_create_by( action_user: action_user, campaign_page: page ) do |action|
      action.form_data = @params

      # Push the action to our queue which will send it to ActionKit.
      merged_params = @params.merge({email: @params[:action_email_address], slug: page.slug})
      send_to_ak = {type: 'action', params: merged_params}
      ChampaignQueue.push(send_to_ak)

      # Return action since the UI needs it.
      action
    end
  end

  private

  def previous_action
    Action.where(action_user: action_user, campaign_page_id: page).first
  end

  def action_user
    @user ||= ActionUser.find_or_create_by(email: @params[:email])
  end

  def page
    @campaign_page ||= CampaignPage.find(@params[:campaign_page_id])
  end
end

