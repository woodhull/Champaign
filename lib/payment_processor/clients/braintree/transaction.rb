module PaymentProcessor
  module Clients
    module Braintree
      class Transaction < Populator
        # = Braintree::Transaction
        #
        # Wrapper around Braintree's Ruby SDK. This class essentially just stuffs parameters
        # into the keys that are expected by Braintree's class.
        #
        # == Usage
        #
        # Call <tt>PaymentProcessor::Clients::Braintree::Transaction.make_transaction</tt>
        #
        # === Options
        #
        # * +:nonce+    - Braintree token that references a payment method provided by the client (required)
        # * +:amount+   - Billing amount (required)
        # * +:currency+ - Billing currency (required)
        # * +:user+     - Hash of information describing the customer. Must include email, and name (required)
        # * +:customer+ - Instance of existing Braintree customer. Must respond to +customer_id+ (optional)
        attr_reader :result, :action

        def self.make_transaction(nonce:, amount:, currency:, user:, page_id:)
          builder = new(nonce, amount, currency, user, page_id)
          builder.transaction
          builder
        end

        def initialize(nonce, amount, currency, user, page_id)
          @amount = amount
          @nonce = nonce
          @user = user
          @currency = currency
          @page_id = page_id
        end

        def transaction
          @result = ::Braintree::Transaction.sale(options)
          if @result.success?
            @action = ManageBraintreeDonation.create(params: @user.merge(page_id: @page_id), braintree_result: result, is_subscription: false)
            Payment.write_transaction(result, @page_id, @action.member_id, existing_customer)
          else
            Payment.write_transaction(result, @page_id, nil, existing_customer)
          end
        end

        private

        def options
          {
            amount: @amount,
            payment_method_nonce: @nonce,
            merchant_account_id: MerchantAccountSelector.for_currency(@currency),
            options: {
              submit_for_settlement: true,
              # we always want to store in vault unless we're using an existing
              # payment_method_token. we haven't built anything to do that yet,
              # so for now always store the payment method.
              store_in_vault_on_success: true
            },
            customer: customer_options,
            billing: billing_options
          }.tap do |options|
            options[:customer_id] = existing_customer.customer_id if existing_customer.present?
          end
        end
      end
    end
  end
end

