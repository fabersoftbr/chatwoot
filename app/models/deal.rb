class Deal < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :deal_stage
  belongs_to :assignee, class_name: 'User', optional: true

  enum temperature: { cold: 0, warm: 1, hot: 2 }, _prefix: true

  validates :title, presence: true
  validates :value_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :lost_reason_present_in_lost_stage

  before_validation :ensure_account_id
  before_validation :append_to_stage, on: :create
  before_save :sync_closed_at

  scope :open_deals, -> { joins(:deal_stage).where(deal_stages: { stage_type: DealStage.stage_types[:open] }) }
  scope :overdue, -> { open_deals.where(next_action_at: ...Time.current) }
  scope :ordered, -> { order(:position, :id) }

  def move_to!(stage_id:, position:, lost_reason: nil)
    transaction do
      self.lost_reason = lost_reason if lost_reason.present?
      update!(deal_stage_id: stage_id)
      reposition!(stage_id, position)
    end

    true
  end

  # ponytail: reindex is O(n) over one column; swap for a fractional rank if a column ever passes ~500 cards
  def reposition!(stage_id, position)
    siblings = account.deals.where(deal_stage_id: stage_id).where.not(id: id).ordered.to_a
    siblings.insert(position.to_i.clamp(0, siblings.length), self)

    siblings.each_with_index do |deal, index|
      next if deal.position == index

      # rubocop:disable Rails/SkipsModelValidations
      deal.update_column(:position, index)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  private

  def ensure_account_id
    self.account_id ||= contact&.account_id
  end

  def append_to_stage
    self.position = (account&.deals&.where(deal_stage_id: deal_stage_id)&.maximum(:position) || -1) + 1
  end

  def sync_closed_at
    return unless new_record? || deal_stage_id_changed?

    self.closed_at = deal_stage.stage_open? ? nil : (closed_at || Time.current)
  end

  def lost_reason_present_in_lost_stage
    return unless deal_stage&.stage_lost?
    return if lost_reason.present?

    errors.add(:lost_reason, I18n.t('errors.messages.blank'))
  end
end
