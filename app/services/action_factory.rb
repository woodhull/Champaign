class ActionFactory
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def run
    @member = Member.find_or_initialize_by(email: params[:email])
    @new_member = @member.new_record?

    return false if action_exists?

    update_member
    create_action
  end

  def update_member
    @member.assign_attributes(params[:member])
    @member.save if @new_member || @member.changed?
  end

  def create_action
    Action.create({
      member: @member,
      page:   page,
      form_data: params[:form_data],
      subscribed_member: @new_member
    })
  end

  def action_exists?
    @action_exists ||= Action.exists?(member: @member, page_id: page)
  end

  def page
    @page ||= Page.find(params[:page_id])
  end
end
