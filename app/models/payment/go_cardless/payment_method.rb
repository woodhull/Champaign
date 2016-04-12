class Payment::GoCardless::PaymentMethod < ActiveRecord::Base
  include AASM

  aasm do
    state :pending, initial: true
    state :created
    state :submitted
    state :active
    state :cancelled
    state :expired

    event :run_create do
      transitions from: [:pending], to: :created
    end

    event :run_submit do
      transitions from: [:pending, :created], to: :submitted
    end

    event :run_activate do
      transitions from: [:pending, :created, :submitted], to: :active
    end

    event :run_cancel do
      transitions from: [:active], to: :cancelled
    end
  end

  belongs_to :customer, class_name: 'Payment::GoCardless::Customer'

  validates :go_cardless_id, presence: true, allow_blank: false
end
