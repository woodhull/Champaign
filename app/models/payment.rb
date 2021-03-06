module Payment
  class << self
    def table_name_prefix
      'payment_'
    end

    def write_transaction(bt_result, page_id, member_id, existing_customer, save_customer=true)
      BraintreeTransactionBuilder.build(bt_result, page_id, member_id, existing_customer, save_customer)
    end

    def write_subscription(subscription_result, page_id, action_id, currency)
      if subscription_result.success?
        Payment::BraintreeSubscription.create({
          subscription_id:        subscription_result.subscription.id,
          amount:                 subscription_result.subscription.price,
          merchant_account_id:    subscription_result.subscription.merchant_account_id,
          action_id:              action_id,
          currency:               currency,
          page_id:                page_id
        })
      end
    end

    def write_customer(bt_customer, bt_payment_method, member_id, existing_customer)
      BraintreeCustomerBuilder.build(bt_customer, bt_payment_method, member_id, existing_customer)
    end

    def customer(email)
      customer = Payment::BraintreeCustomer.find_by(email: email)
      return customer if customer.present?
      member = Member.find_by(email: email)
      member.try(:customer)
    end
  end

  class BraintreeCustomerBuilder
    def self.build(bt_customer, bt_payment_method, member_id, existing_customer)
      new(bt_customer, bt_payment_method, member_id, existing_customer).build
    end

    def initialize(bt_customer, bt_payment_method, member_id, existing_customer)
      @bt_customer = bt_customer
      @customer = existing_customer
      @member_id = member_id
      @bt_payment_method = bt_payment_method
    end

    def build
      if @customer.present?
        @customer.update(customer_attrs)
      else
        @customer = Payment::BraintreeCustomer.create(customer_attrs)
      end
      Payment::BraintreePaymentMethod.find_or_create_by!(
        customer: @customer,
        token:    @bt_payment_method.token
      )
    end

    def customer_attrs
      card_attrs.merge({
        customer_id:      @bt_customer.id,
        member_id:        @member_id,
        email:            @bt_customer.email
      })
    end

    def card_attrs
      if @bt_payment_method.is_a? Braintree::CreditCard
        @bt_payment_method.instance_eval do
          {
            card_type:        card_type,
            card_bin:         bin,
            cardholder_name:  cardholder_name,
            card_debit:       debit,
            card_last_4:      last_4,
            card_unique_number_identifier: unique_number_identifier
          }
        end
      else
        {
          card_last_4: 'PYPL' # for now, assume PayPal if not CC
        }
      end
    end
  end

  class BraintreeTransactionBuilder
    #
    # Stores and associates a Braintree transaction as +Payment::BraintreeTransaction+. Builder will also
    # create or update an instance of +Payment::BraintreeCustomer+, if save_customer is passed
    #
    # === Options
    #
    # * +:bt_result+   - A Braintree::Transaction response object or a Braintree::Subscription response
    #                    (see https://developers.braintreepayments.com/reference/response/transaction/ruby)
    #                    or a Braintree::WebhookNotification
    # * +:page_id+     - the id of the Page to associate with the transaction record
    # * +:member_id+   - the member_id to associate with the customer record
    # * +:existing_customer+ - if passed, this customer is updated instead of creating a new one
    # * +:save_customer+     - optional, default true. whether to save the customer info too
    #
    #

    def self.build(bt_result, page_id, member_id, existing_customer, save_customer=true)
      new(bt_result, page_id, member_id, existing_customer, save_customer).build
    end

    def initialize(bt_result, page_id, member_id, existing_customer, save_customer=true)
      @bt_result = bt_result
      @page_id = page_id
      @member_id = member_id
      @save_customer = save_customer
      @existing_customer = existing_customer
    end

    def build
      return unless transaction.present?
      # a Payment::BraintreeCustomer gets created for both successful and failed transactions. The customer_id will be nil,
      # though, because transaction.customer_details.id is nil for failed transaction.
      # For webhooks, @existing_customer will be present.
      @customer = @existing_customer || Payment::BraintreeCustomer.find_or_create_by!(
          member_id: @member_id,
          customer_id: transaction.customer_details.id)
      # If the transaction was a failure, there is no payment method - don't persist a nil payment method locally.
      # Make the foreign key to the payment method token nil for the locally persisted failed transaction.
      @local_payment_method_id = payment_method_token.blank? ? nil : Payment::BraintreePaymentMethod.find_or_create_by!(
          customer: @customer,
          token: payment_method_token).id
      ::Payment::BraintreeTransaction.create!(transaction_attrs)
      return unless successful? && @save_customer
      @customer.update(customer_attrs)
    end

    private

    def transaction_attrs
      {
        transaction_id:                  transaction.id,
        transaction_type:                transaction.type,
        payment_instrument_type:         transaction.payment_instrument_type,
        amount:                          transaction.amount,
        transaction_created_at:          transaction.created_at,
        merchant_account_id:             transaction.merchant_account_id,
        processor_response_code:         transaction.processor_response_code,
        currency:                        transaction.currency_iso_code,
        customer_id:                     @customer.customer_id,
        status:                          status,
        payment_method_id:               @local_payment_method_id,
        page_id:                         @page_id
      }
    end

    def customer_attrs
      {
        # NOTE: we do NOT store card_unique_number_identifier because
        # that is only returned on Braintree::CreditCard, not on
        # Braintree::Transaction::CreditCardDetails
        card_type:                 card.card_type,
        card_bin:                  card.bin,
        cardholder_name:           card.cardholder_name,
        card_debit:                card.debit,
        card_last_4:               last_4,
        customer_id:               transaction.customer_details.id,
        email:                     transaction.customer_details.email,
        member_id:                 @member_id
      }
    end

    def transaction
      @bt_result.transaction || @bt_result.subscription.try(:transactions).try(:first)
    end

    def card
      transaction.credit_card_details
    end

    def status
      Payment::BraintreeTransaction.statuses[(successful? ? :success : :failure)]
    end

    def successful?
      return @bt_result.success? if @bt_result.respond_to?(:success?)
      if @bt_result.is_a?(Braintree::WebhookNotification) && @bt_result.kind == 'subscription_charged_successfully'
        return true
      end
      false
    end

    def last_4
      transaction.payment_instrument_type == "paypal_account" ? 'PYPL' : card.last_4
    end

    def payment_method_token
      case transaction.payment_instrument_type
      when "credit_card"
        transaction.credit_card_details.try(:token)
      when "paypal_account"
        transaction.paypal_details.try(:token)
      else
        nil
      end
    end
  end
end

