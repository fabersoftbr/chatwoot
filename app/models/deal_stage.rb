class DealStage < ApplicationRecord
  DEFAULT_STAGES = [
    { name: 'Prospectado', color: '#6B7280', stage_type: :open },
    { name: 'Em negociação', color: '#3B82F6', stage_type: :open },
    { name: 'Contrato enviado', color: '#8B5CF6', stage_type: :open },
    { name: 'Ganho', color: '#10B981', stage_type: :won },
    { name: 'Perdido', color: '#EF4444', stage_type: :lost }
  ].freeze

  belongs_to :account
  has_many :deals, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, presence: true

  enum stage_type: { open: 0, won: 1, lost: 2 }, _prefix: :stage

  scope :ordered, -> { order(:position, :id) }

  def self.seed_defaults(account)
    return account.deal_stages.ordered if account.deal_stages.exists?

    # ponytail: account-level lock serializes concurrent first-calls so they
    # don't each pass the exists? check and double-seed. Upgrade path: a
    # unique DB constraint on (account_id, position) if this ever needs to
    # scale past a single-row lock.
    account.with_lock do
      unless account.deal_stages.exists?
        DEFAULT_STAGES.each_with_index do |attributes, index|
          account.deal_stages.create!(attributes.merge(position: index))
        end
      end
    end

    account.deal_stages.ordered
  end
end
