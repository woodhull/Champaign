class ActionFactory
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def run
    @member = Member.find_or_initialize_by(email: params[:email])
    @is_new_member = @member.new_record?

    return false if action_exists?

    update_member
    create_action
  end

  def update_member
    @member.assign_attributes(params[:member])
    @member.save if @is_new_member || @member.changed?
  end

  def create_action
    Action.create({
      member: @member,
      page_id: params[:page_id],
      form_data: params[:form_data],
      subscribed_member: @is_new_member
    })
  end

  def action_exists?
    @action_exists ||= Action.exists?(member: @member, page_id: params[:page_id])
  end
end
