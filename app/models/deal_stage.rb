class DealStage < ApplicationRecord
  DEFAULT_STAGES = [
    { name: 'Prospectado', color: '#6B7280', stage_type: :open },
    { name: 'Em negociação', color: '#3B82F6', stage_type: :open },
    { name: 'Contrato enviado', color: '#8B5CF6', stage_type: :open },
    { name: 'Ganho', color: '#10B981', stage_type: :won },
    { name: 'Perdido', color: '#EF4444', stage_type: :lost }
  ].freeze

  belongs_to :account
  belongs_to :pipeline
  has_many :deals, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, presence: true

  enum stage_type: { open: 0, won: 1, lost: 2 }, _prefix: :stage

  scope :ordered, -> { order(:position, :id) }

  before_validation :ensure_account_id
  before_destroy :ensure_not_last_closing_stage, prepend: true

  private

  def ensure_account_id
    self.account_id ||= pipeline&.account_id
  end

  def ensure_not_last_closing_stage
    return if destroyed_by_association.present?
    return if stage_open?
    return if pipeline.deal_stages.where(stage_type: stage_type).where.not(id: id).exists?

    errors.add(:base, I18n.t('errors.deal_stages.last_closing_stage'))
    throw :abort
  end
end
