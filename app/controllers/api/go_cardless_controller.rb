class GoCardlessDirector
  def initialize(session_id, success_url)
    @session_id = session_id
    @success_url = success_url

  end

  def redirect_url
    redirect_flow_instance.redirect_url
  end

  def redirect_flow_instance
    @redirect_flow_instance ||= client.redirect_flows.create(params: {
      session_token:        @session_id,
      success_redirect_url: @success_url
    })
  end

  def client
    @client ||= GoCardlessPro::Client.new(
      access_token: Settings.gocardless.token,
      environment:  Settings.gocardless.environment.to_sym
    )
  end
end

class HandleGoCardless
  def initialize(params)
    @params = params
  end

  def run
    response = client.subscriptions.create(params: subscription_options)

    if response.api_response.status_code == 200
      ActionFactory.new(@params).run
    end
  end

  def mandate
    @mandate ||= client.mandates.get(complete_redirect_flow.links.mandate)
  end

  def amount
    original_amount = (@params[:amount].to_f * 100).to_i

    @amount ||= PaymentProcessor::Currency.convert(
      original_amount, currency, @params[:currency].upcase
    ).cents
  end

  def currency
    {
      'bacs'     => 'GBP',
      'autogiro' => 'SEK'
    }.fetch(mandate.scheme.downcase, 'EUR')
  end

  def complete_redirect_flow
    @complete_redirect_flow ||= client.redirect_flows.
      complete(@params[:redirect_flow_id], params: { session_token: @params[:session_id]})

  rescue GoCardlessPro::InvalidStateError => e
    @errors = e.errors unless e.message =~ /already completed/
    @complete_redirect_flow = client.redirect_flows.get(@redirect_flow_id)
  end

  def client
    GoCardlessPro::Client.new(
      access_token: Settings.gocardless.token,
      environment:  Settings.gocardless.environment.to_sym
    )
  end

  def self.success?
    @errors.blank?
  end

  def payment_options
    {
      amount: amount,
      currency: currency,
      links: {
        mandate: mandate.id
      },
      metadata: {
        customer_id: complete_redirect_flow.links.customer
      }
    }
  end

  def subscription_options
    payment_options.merge({
      name: "donation",
      interval_unit: "monthly",
      day_of_month:  "1"
    })
  end
end

class Api::GoCardlessController < ApplicationController
  skip_before_action :verify_authenticity_token

  def start_flow
    flow = GoCardlessDirector.new(session.id, success_url)
    redirect_to flow.redirect_url
  end

  def payment_complete
    puts params
    HandleGoCardless.new(gc_params).run
    render json: params
  end

  def webhook
    signature = response.headers["Webhook-Signature"]

    head :ok
  end

  private

  def builder
    PaymentProcessor::GoCardless::Transaction
  end

  def success_url
    local_params =  Rack::Utils.parse_query(
      URI.parse(request.url).query
    ).merge( params ).to_query

    "#{request.base_url}/api/go_cardless/payment_complete?#{local_params}"
  end

  def gc_params
    form_fields = Form.find(params[:form_id]).form_elements.map(&:name)
    base_params = %w{page_id form_id name source akid referring_akid}

    permitted = params.permit( form_fields + base_params )

    fullname = NameSplitter.new(full_name: params[:user][:name])

    {
      email: base_params[:email],
      page_id: page.id,
      amount: params[:amount],
      curreny: params[:currency],
      member: {
        first_name: fullname.first_name,
        last_name:  fullname.last_name
      },
      form_data: permitted
    }
  end

  def page
    @page ||= Page.find(params[:page_id])
  end
end
