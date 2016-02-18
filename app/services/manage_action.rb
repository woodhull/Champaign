class BuildAction
  def self.create(params)
    new(params).create
  end

  def initialize(params)
    @params = params
    !!existing_member
    @existing_member = Member.find_by( email: @params[:email] )
  end

  def build_action
    Action.create(
      member: member,
      page:   page,
      form_data: @params,
      subscribed_member: !existing_member?
    )
  end

  private

  def subscribe_member
    member = Member.new(email: @params[:email])

    if @params.has_key? :name
      @user.name = @params[:name]
    end

    @params[:actionkit_user_id] = actionkit_user_id(@params[:akid]) if @params.has_key? :akid

    @user.assign_attributes(filtered_params)
    @user.save if @user.changed
    @user
  end

  def filtered_params
    hash = @params.try(:to_unsafe_hash) || @params.to_h # for ActionController::Params
    hash.symbolize_keys.compact.keep_if{ |k| permitted_keys.include? k }
  end

  def permitted_keys
    Member.new.attributes.keys.map(&:to_sym).reject!{|k| k == :id}
  end

  def page
    @page ||= Page.find(@params[:page_id])
  end

  def actionkit_user_id(akid)
    AkidParser.parse(akid)[:actionkit_user_id]
  end

  def increment_counters
    Analytics::Page.increment(page.id, new_member: !existing_member?)
  end


  def existing_member?
    !!@existing_member
  end
end

class ManageAction
  include ActionBuilder

  def self.create(params)
    new(params).create
  end

  def initialize(params)
    @params = params
  end

  def create
    return previous_action if previous_action.present?

    ChampaignQueue.push(queue_message)
    build_action
  end

  private

  def queue_message
    {
      type: 'action',
      params: {
        page: "#{page.slug}-petition"
      }.merge(@params)
    }
  end
end

