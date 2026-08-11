class DealActivity < ApplicationRecord
  MANUAL_TYPES = %w[note call meeting email].freeze

  belongs_to :account
  belongs_to :deal
  belongs_to :user, optional: true

  enum activity_type: {
    stage_changed: 0,
    temperature_changed: 1,
    assigned: 2,
    note: 3,
    call: 4,
    meeting: 5,
    email: 6,
    created: 7
  }

  before_validation :ensure_account_id

  validates :activity_type, presence: true
  validates :content, presence: true, if: -> { MANUAL_TYPES.include?(activity_type) }

  scope :latest, -> { order(created_at: :desc, id: :desc) }

  private

  def ensure_account_id
    self.account_id ||= deal&.account_id
  end
end
