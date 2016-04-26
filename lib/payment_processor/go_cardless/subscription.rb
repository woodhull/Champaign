module PaymentProcessor
  module GoCardless
    class Subscription < Populator
      attr_reader :error, :action

      def self.make_subscription(params)
        builder = new(params)
        builder.subscribe
        builder
      end

      def initialize(amount:, currency:, user:, page_id:, redirect_flow_id:, session_token:)
        @page_id = page_id
        @original_amount_in_cents = (amount.to_f * 100).to_i # Price in pence/cents
        @original_currency = currency.try(:upcase)
        @redirect_flow_id = redirect_flow_id
        @user = user
        @session_token = session_token
      end

      def subscribe
        subscription = client.subscriptions.create(params: subscription_params)

        @local_subscription = Payment::GoCardless.write_subscription(subscription.id, amount_in_whole_currency, currency, @page_id)
        @action = ManageDonation.create(params: action_params)
        @local_customer = Payment::GoCardless.write_customer(customer_id, @action.member_id)
        @local_mandate = Payment::GoCardless.write_mandate(mandate.id, mandate.scheme, mandate.next_possible_charge_date, @local_customer.id)
      rescue GoCardlessPro::Error => e
        @error = e
      end

      def subscription_id
        @local_subscription.try(:go_cardless_id)
      end

      private

      def action_params
        @user.merge!(
          page_id:              @page_id,
          amount:               amount_in_whole_currency.to_s,
          card_num:             mandate.id,
          currency:             currency,
          subscription_id:      @local_subscription.go_cardless_id,
          is_subscription:      true,
          recurrence_number:    0,
          card_expiration_date: nil
        )
      end

    end
  end
end

