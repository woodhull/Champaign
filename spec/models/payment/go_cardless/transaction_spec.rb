require 'rails_helper'

describe Payment::GoCardless::Transaction do

  let(:transaction) { build :payment_go_cardless_transaction }
  subject { transaction }

  it { is_expected.to respond_to :go_cardless_id }
  it { is_expected.to respond_to :amount }
  it { is_expected.to respond_to :currency }
  it { is_expected.to respond_to :charge_date }
  it { is_expected.to respond_to :amount_refunded }
  it { is_expected.to respond_to :reference }
  it { is_expected.to respond_to :created_at }
  it { is_expected.to respond_to :updated_at }

  # Associations
  it { is_expected.to respond_to :page }
  it { is_expected.to respond_to :page_id }
  it { is_expected.to respond_to :payment_method }
  it { is_expected.to respond_to :payment_method_id }
  it { is_expected.to respond_to :customer }
  it { is_expected.to respond_to :customer_id }

  it 'handles amount as BigDecimal' do
    create :payment_go_cardless_transaction, amount: 12.41
    create :payment_go_cardless_transaction, amount: 10701.11
    expect(Payment::GoCardless::Transaction.all.map(&:amount).sum).to eq 10713.52
    expect(Payment::GoCardless::Transaction.last.amount.class).to eq BigDecimal
  end

  it 'handles amount_refunded as BigDecimal' do
    create :payment_go_cardless_transaction, amount_refunded: 12.51
    create :payment_go_cardless_transaction, amount_refunded: 10701.11
    expect(Payment::GoCardless::Transaction.all.map(&:amount_refunded).sum).to eq 10713.62
    expect(Payment::GoCardless::Transaction.last.amount.class).to eq BigDecimal
  end

  describe 'associations' do
    it 'associates customer with a GoCardless::Customer' do
      expect{ transaction.customer = build :payment_go_cardless_customer }.not_to raise_error
    end

    it 'associates payment_method with a GoCardless::PaymentMethod' do
      expect{ transaction.payment_method = build :payment_go_cardless_payment_method }.not_to raise_error
    end
  end

  describe 'validation' do
    before :each do
      expect(transaction).to be_valid
    end

    it 'rejects blank go_cardless_id' do
      transaction.go_cardless_id = ''
      expect(transaction).to be_invalid
    end
  end

 describe 'state' do
    subject { create :payment_go_cardless_transaction }

    it 'has initial state' do
      expect(subject.pending_customer_approval?).to be(true)
    end

    context 'submission allowed' do
      it 'from pending_customer_approval' do
        expect{
          subject.run_submit!
        }.to change{ subject.reload.submitted? }.from(false).to(true)
      end

      it 'from pending_submission' do
        subject.update(aasm_state: :pending_submission)

        expect{
          subject.run_submit!
        }.to change{ subject.reload.submitted? }.from(false).to(true)
      end
    end

    context 'confirmation allowed' do
      it 'from pending_customer_approval' do
        expect{
          subject.run_confirm!
        }.to change{ subject.reload.confirmed? }.from(false).to(true)
      end

      it 'from pending_submission' do
        subject.update(aasm_state: :pending_submission)

        expect{
          subject.run_confirm!
        }.to change{ subject.reload.confirmed? }.from(false).to(true)
      end

      it 'from submitted' do
        subject.update(aasm_state: :submitted)

        expect{
          subject.run_confirm!
        }.to change{ subject.reload.confirmed? }.from(false).to(true)
      end
    end

    context 'pay out allowed' do
      it 'from pending_customer_approval' do
        expect{
          subject.run_payout!
        }.to change{ subject.reload.paid_out? }.from(false).to(true)
      end

      it 'from pending_submission' do
        subject.update(aasm_state: :pending_submission)

        expect{
          subject.run_payout!
        }.to change{ subject.reload.paid_out? }.from(false).to(true)
      end

      it 'from submitted' do
        subject.update(aasm_state: :submitted)

        expect{
          subject.run_payout!
        }.to change{ subject.reload.paid_out? }.from(false).to(true)
      end

      it 'from confirmed' do
        subject.update(aasm_state: :confirmed)

        expect{
          subject.run_payout!
        }.to change{ subject.reload.paid_out? }.from(false).to(true)
      end
    end

    it 'can be cancelled' do
      expect{
        subject.run_cancel!
      }.to change{ subject.reload.cancelled? }.from(false).to(true)
    end

    it 'can be denied' do
      expect{
        subject.run_deny!
      }.to change{ subject.reload.customer_approval_denied? }.from(false).to(true)
    end

    it 'can be charged back' do
      expect{
        subject.run_charge_back!
      }.to change{ subject.reload.charged_back? }.from(false).to(true)
    end

    it 'can be failed' do
      expect{
        subject.run_fail!
      }.to change{ subject.reload.failed? }.from(false).to(true)
    end
  end
end
