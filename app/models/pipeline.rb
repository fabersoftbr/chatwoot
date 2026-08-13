class Pipeline < ApplicationRecord
  DEFAULT_NAME = 'Funil padrão'.freeze

  belongs_to :account
  has_many :deal_stages, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(:position, :id) }

  after_create :seed_default_stages
  before_destroy :flag_deal_stages_for_cascade_destroy, prepend: true

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

  def flag_deal_stages_for_cascade_destroy
    deal_stages.each { |stage| stage.cascading_pipeline_destroy = true }
  end
end
