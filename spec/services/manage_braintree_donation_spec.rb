require 'rails_helper'
describe ManageBraintreeDonation do

  let(:braintree_arguments) do
    {
      amount: "100.00",
      merchant_account_id: 'GBP',
      payment_method_nonce: payment_nonce,
      options: {
        store_in_vault: true,
        submit_for_settlement: true
      }
    }
  end

  let(:transaction) do
    VCR.use_cassette('manage braintree donation transaction') do
      Braintree::Transaction.sale( braintree_arguments )
    end
  end

  let(:paypal_transaction) do
    VCR.use_cassette('manage braintree donation paypal transaction') do
      Braintree::Transaction.sale( braintree_arguments )
    end
  end

  let(:subscription) do
    VCR.use_cassette('manage braintree donation subscription') do
      Braintree::Subscription.create(
        price: '1.00',
        payment_method_token:  transaction.transaction.credit_card_details.token,
        merchant_account_id: 'EUR',
        plan_id: 'EUR'
      )
    end
  end

  let(:queue_arguments) do
    {
      type: 'donation',
      params: {
        donationpage: {
          name: "foo-bar-donation",
          payment_account: payment_account
        },
        order: {
         amount: "100.0",
         card_num: "1881",
         card_code: "007",
         exp_date_month: "12",
         exp_date_year: "2020",
         currency: "GBP"
        },
        action: {
          source: nil
        },
        user: {
         country: "Bolivia",
         email: "foo@example.com",
         card_num: "1881",
         is_subscription: false,
         amount: '100.0',
         currency: "GBP",
         transaction_id:  /[a-z0-9]*$/,
         first_name: "Bob",
         last_name: "Murphy"
        }
      }
    }
  end


  let(:page) { create(:page, slug: 'foo-bar') }

  let(:params) do
    { page_id: page.id, country: 'Bolivia', email: 'foo@example.com', name: 'Bob Murphy' }
  end

  subject {
    ManageBraintreeDonation.create({
      params: params,
      braintree_result: transaction,
      is_subscription: false
    })
  }

  before do
    allow( Analytics::Page ).to receive(:increment)
    allow( ChampaignQueue ) .to receive(:push)
  end

  describe 'With PayPal Transaction' do
    let(:payment_nonce)   { 'fake-paypal-future-nonce' }
    let(:payment_account) { 'dd' }
    subject {
      ManageBraintreeDonation.create({
        params: params,
        braintree_result: paypal_transaction,
        is_subscription: false
      })
    }

    it 'is' do
      expect(ChampaignQueue).to receive(:push).with( hash_including(queue_arguments) )
      subject
    end
  end

  describe 'Subscription' do
    subject {
      ManageBraintreeDonation.create({
        params: params,
        braintree_result: subscription,
        is_subscription: false
      })
    }

    it 'creates' do
      expect(ChampaignQueue).to receive(:push).with({})
      subject
    end
  end

  describe 'action' do
    it 'is created' do
      expected_arguments = {
        page:       page,
        form_data:  params
      }

      expect(Action).to receive(:create).with( hash_including(expected_arguments) )
      subject
    end
  end

  describe 'cache counters' do
    context 'with new member' do
      it 'increments with new_member as true' do
        expect(Analytics::Page).to receive(:increment).with(page.id, new_member: true)
        subject
      end
    end

    context 'with existing member' do
      let!(:member) { create(:member, email: 'foo@example.com') }

      it 'increments with new_member as false' do
        expect(Analytics::Page).to receive(:increment).with(page.id, new_member: false)
        subject
      end
    end
  end

  describe 'ChampaignQueue' do
    it 'is "pushed" to' do
      expect(ChampaignQueue).to receive(:push).with(expected)
      subject
    end
  end
end


















describe ManageBraintreeDonation do
  # Hey, let's define a new class that makes testing this possible

  class DeepStruct < OpenStruct
    # Shamelessly copied from http://andreapavoni.com/blog/2013/4/create-recursive-openstruct-from-a-ruby-hash/#.Vm8bmxqDFBc
    def initialize(hash=nil)
      @table = {}
      @hash_table = {}

      if hash
        hash.each do |k, v|
          @table[k.to_sym] = (v.is_a?(Hash) ? self.class.new(v) : v)
          @hash_table[k.to_sym] = v

          new_ostruct_member(k)
        end
      end
    end

    def to_h
      @hash_table
    end
  end

  let(:page) { create(:page, slug: 'test') }
  let!(:user) { create(:member, email: 'bob@example.com', country: 'US', name: 'Stringer Bell')}
  let(:data) { {email: user.email, page_id: page.id, name: user.name} }
  let(:transaction_attributes) {
    {
        transaction: {
            id: 'test',
            type: 'sale',
            amount: '1.0',
            currency_iso_code: 'GBP',
            status: 'submitted for settlement',
            created_at: Time.now,
            updated_at: Time.now,
            credit_card_details: {
              token: nil,
              bin: '41111',
              last_4: '1111',
              card_type: 'Visa',
              expiration_date: '01/2016',
              cardholder_name: nil,
              customer_location: 'US',
              prepaid: 'Unknown',
              healthcare: 'Unknown',
              durbin_regulated: 'Unknown',
              debit: 'Unknown',
              commercial: 'Unknown',
              payroll: 'Unknown',
              country_of_issuance: 'Unknown'
            },
            customer_details: {
              id: '12345',
              first_name: 'Eric Boersma',
              last_name: nil,
              email: user.email
            },
            subscription_details: {
              billing_period_start_date: nil,
              billing_period_end_date: nil
            }
        }

    }


  }

  let(:result) { DeepStruct.new(transaction_attributes) }
  let(:webhook_attributes) {
    {
        subscription: {
            transactions: [result.transaction]
        }
    }
  }
  let(:webhook_notification) {
    DeepStruct.new(webhook_attributes)
  }


  let(:full_donation_options) {
    {
        donationpage: {
            name: 'test-donation',
            payment_account: 'Braintree GBP'
        },
        order: {
            amount: '1.0',
            card_num: '1111',
            card_code: '007',
            exp_date_month: '01',
            exp_date_year: '2016',
            currency: 'GBP',
            is_subscription: false,
            transaction_id: 'test'
        },
        action: {
            source: nil
        },
        user: {
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            country: 'US'
        }
    }
  }

  let(:expected_queue_message) {
    {
        type: 'donation',
        params: full_donation_options
    }
  }

  before do
    allow(ChampaignQueue).to receive(:push)
  end

  describe 'with new member' do
    let(:data) { {email: 'new_member@example.com', page_id: page.id, name: 'Bob' }   }

    before do
      transaction_attributes[:cutomer_details][:email] = 'new_member@example.com'
    end

    it 'increments redis counter as new member' do
      expect(Analytics::Page).to receive(:increment).with(page.id, new_member: true)
      ManageBraintreeDonation.create(params: data, braintree_result: result)
    end
  end

  it 'increments redis counter as existing member' do
    expect(Analytics::Page).to receive(:increment).with(page.id, new_member: false)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  describe 'source' do
    it 'passes source if passed' do
      expect(ChampaignQueue).to receive(:push).with(a_hash_including(
        params: a_hash_including( action: { source: 'fb' } )
      ))
      ManageBraintreeDonation.create(params: data.merge(source: 'fb'), braintree_result: result)
    end

    it 'passes nil if source not passed' do
      expect(ChampaignQueue).to receive(:push).with(a_hash_including(
        params: a_hash_including( action: { source: nil } )
      ))
      ManageBraintreeDonation.create(params: data, braintree_result: result)
    end
  end

  it 'creates the right kind of request' do
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  it 'can handle not having an expiration date' do
    result.transaction.credit_card_details.expiration_date = '/'
    expect(result.transaction.credit_card_details.expiration_date).to eq('/')
    full_donation_options[:order][:exp_date_month] = Time.now.month.to_s
    full_donation_options[:order][:exp_date_year] = (Time.now.year + 5).to_s
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  it 'passes along a nil credit card number' do
    result.transaction.credit_card_details.last_4 = nil
    expect(result.transaction.credit_card_details.last_4).to eq(nil)
    full_donation_options[:order][:card_num] = nil
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  it 'passes Paypal when thats the appropriate payment_instrument_type' do
    result.transaction.payment_instrument_type = 'paypal_account'
    full_donation_options[:order][:card_num] = ManageBraintreeDonation::PAYPAL_IDENTIFIER
    full_donation_options[:donationpage][:payment_account] = "PayPal GBP"
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  it 'can handle a subscription event and send the proper information' do
    result.subscription = instance_double('Braintree::Subscription', transactions: [result.transaction])
    deleted_transaction = result.delete_field('transaction')
    expect(result.transaction).to eq(nil)
    expect(result.subscription.transactions[0]).to eq(deleted_transaction)
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: result)
  end

  it 'can handle a subscription event after the initial signup and send the proper information' do
    expect(ChampaignQueue).to receive(:push).with(expected_queue_message)
    ManageBraintreeDonation.create(params: data, braintree_result: webhook_notification)
  end
end
