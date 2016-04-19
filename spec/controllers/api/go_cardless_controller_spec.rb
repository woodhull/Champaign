require 'rails_helper'

describe Api::GoCardlessController do
  before do
    allow(request.session).to receive(:id) { 'fake_session_id' }
  end

  describe 'GET #start_flow' do
    let(:director) { double(:director, redirect_url: "http://example.com/redirect_url") }

    before do
      allow(GoCardlessDirector).to receive(:new){ director }

      subject
    end

    subject { get :start_flow, page_id: '1', foo: 'bar' }

    it 'instantiates GoCardlessDirector' do
      expect(GoCardlessDirector).to have_received(:new).
        with('fake_session_id', "http://test.host/api/go_cardless/payment_complete?foo=bar&page_id=1")
    end

    it 'redirects' do
      expect(response).to redirect_to 'http://example.com/redirect_url'
    end
  end

  describe 'GET #payment_complete' do
    let(:builder) { double(:builder, result: double(:result, success?: true)) }

    before do
      allow(PaymentProcessor::GoCardless::Transaction).to receive(:make_transaction){ builder }
      subject
    end

    subject { get :payment_complete, foo: 'bar' }

    it 'creates GC transaction' do
      expect(PaymentProcessor::GoCardless::Transaction).to(
        have_received(:make_transaction).with(hash_including({'foo' => 'bar'}), 'fake_session_id')
      )
    end
  end
end

describe HandleGoCardless, :focus do
  let(:page) { create(:page) }

  let(:params) do
    {
      amount: '2',
      currency: 'EUR',
      page_id: page.id,
      recurring: false,
      session_id: '1234',
      redirect_flow_id: "RE00004AGEQT5S4ABV1NT8TBA5CZ1VG4",
      user: {
        country: 'GB',
        email: 'foo@example.com',
        name: "Rufus Sebastio",
        postal: "W1"
      }
    }
  end

  let(:params) do
    {
      session_id: '1234',
      redirect_flow_id: "RE00004AGEQT5S4ABV1NT8TBA5CZ1VG4",
      email: 'foo@example.com',
      page_id: page.id,
      amount: '2',
      currency: 'EUR',
      member: {
        email: "foo@example.com",
        name:  "Rufus Sebastio"
      },
      form_data: {}
    }
  end

  before(:all) do
    VCR.turn_off!
  end

  after(:all) do
    VCR.turn_on!
  end

  before do
    stub_request(
      :post, "https://api-sandbox.gocardless.com/redirect_flows/RE00004AGEQT5S4ABV1NT8TBA5CZ1VG4/actions/complete"
    ).to_return(
      body: {
        'redirect_flows' => {
          'created_at' => 'created_at-input',
          'description' => 'description-input',
          'id' => 'id-input',
          'links' => { mandate: 'ddfst43' },
          'redirect_url' => 'redirect_url-input',
          'scheme' => 'scheme-input',
          'session_token' => 'session_token-input',
          'success_redirect_url' => 'success_redirect_url-input'
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' }
    )

    stub_request(:get, "https://api-sandbox.gocardless.com/mandates/ddfst43").
       to_return(
        body: {
          'mandates' => {
            'created_at' => Time.now,
            'id' => 'id-input',
            'links' => 'links-input',
            'metadata' => 'metadata-input',
            'next_possible_charge_date' => 'next_possible_charge_date-input',
            'reference' => 'reference-input',
            'scheme' => 'scheme-input',
            'status' => 'status-input'
          }
        }.to_json,

        headers: { 'Content-Type' => 'application/json' }
      )

    #with(:body => "{\"data\":{\"session_token\":\"1234\"}}"
  end

  context "subscription" do
    before do
      params[:recurring] = true

      stub_request(:post, "https://api-sandbox.gocardless.com/subscriptions").
        to_return(
          body: {
            'subscriptions' =>
              {
                'amount' => 'amount-input',
                'count' => 'count-input',
                'created_at' => 'created_at-input',
                'currency' => 'currency-input',
                'day_of_month' => 'day_of_month-input',
                'end_date' => 'end_date-input',
                'id' => 'id-input',
                'interval' => 'interval-input',
                'interval_unit' => 'interval_unit-input',
                'links' => 'links-input',
                'metadata' => 'metadata-input',
                'month' => 'month-input',
                'name' => 'name-input',
                'payment_reference' => 'payment_reference-input',
                'start_date' => 'start_date-input',
                'status' => 'status-input',
                'upcoming_payments' => 'upcoming_payments-input'
              }

          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'creates a new member' do
      HandleGoCardless.new(params).run

      expect(
        Member.first.attributes
      ).to include({
        "email"       => "foo@example.com",
        "country"     => "GB",
        "first_name"  => "Rufus",
        "last_name"   => "Sebastio"
      })
    end

    it 'creates an action' do
      HandleGoCardless.new(params).run
      expect(Action.count).to eq(1)
    end
  end
end
