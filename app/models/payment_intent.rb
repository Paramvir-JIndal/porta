# frozen_string_literal: true

class PaymentIntent < ApplicationRecord
  STRIPE_STATUS_SUCCEEDED = 'succeeded'
  SUCCEEDED_STATES = [STRIPE_STATUS_SUCCEEDED].freeze

  STRIPE_PAYMENT_INTENT_SUCCEEDED = [Stripe::PaymentIntent::OBJECT_NAME, STRIPE_STATUS_SUCCEEDED].join('.').freeze

  belongs_to :invoice, inverse_of: :payment_intents

  validates :invoice, :payment_intent_id, :state, presence: true
  validates :payment_intent_id, :state, length: { maximum: 255 }

  scope :latest, -> (count = 1) { reorder(created_at: :desc, id: :desc).limit(count) }
  scope :latest_pending, -> (count = 1) { where.not(state: SUCCEEDED_STATES).latest(count) }

  scope :by_invoice, ->(invoice) { where(invoice: invoice) }

  def succeeded?
    SUCCEEDED_STATES.include?(state)
  end

  def update_from_stripe_event(event)
    return unless event.type == STRIPE_PAYMENT_INTENT_SUCCEEDED
    return if succeeded? || invoice.paid?

    payment_intent_data = event.data.object

    transaction do
      self.state = payment_intent_data['status']
      currency = payment_intent_data['currency']&.upcase || invoice.currency
      amount = ThreeScale::Money.cents(payment_intent_data['amount'], currency)
      payment_transaction = build_payment_transaction(amount: amount, reference: payment_intent_data['id'], params: event.to_hash)
      save && payment_transaction.save && invoice.pay
    end
  end

  protected

  def build_payment_transaction(attrs)
    attributes = attrs.reverse_merge(action: :purchase, success: true, message: 'Payment confirmed')
    invoice.payment_transactions.build(attributes, without_protection: true)
  end
end
