class Pipeline < ApplicationRecord
  DEFAULT_NAME = 'Funil padrão'.freeze

  belongs_to :account
  # delete_all, not destroy: DealStage's before_destroy guard refuses to destroy a
  # pipeline's last won or lost stage, and that `throw :abort` propagates out of the
  # dependent-destroy callback and aborts the pipeline's own destroy. The stages of a
  # pipeline being deleted need no per-row callbacks; what those callbacks protected
  # is enforced here instead by refuse_destroy_with_deals.
  has_many :deal_stages, dependent: :delete_all

  validates :name, presence: true

  scope :ordered, -> { order(:position, :id) }

  after_create :seed_default_stages
  before_destroy :refuse_destroy_with_deals, prepend: true

  def self.seed_default(account)
    return account.pipelines.ordered.first if account.pipelines.exists?

    # ponytail: account-level lock serializes concurrent first-calls so two
    # requests can't both pass the exists? check and create two default
    # pipelines. Upgrade path: a unique index on (account_id, position).
    account.with_lock do
      account.pipelines.create!(name: DEFAULT_NAME, position: 0) unless account.pipelines.exists?
    end

    account.pipelines.ordered.first
  end

  def self.resolve(account, id)
    return seed_default(account) if id.blank?

    account.pipelines.find(id)
  end

  private

  def seed_default_stages
    DealStage::DEFAULT_STAGES.each_with_index do |attributes, index|
      deal_stages.create!(attributes.merge(position: index, account_id: account_id))
    end
  end

  def refuse_destroy_with_deals
    return unless account.deals.where(deal_stage_id: deal_stages.select(:id)).exists?

    errors.add(:base, I18n.t('errors.pipelines.has_deals'))
    throw :abort
  end
end
