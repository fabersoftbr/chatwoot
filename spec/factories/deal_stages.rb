FactoryBot.define do
  factory :deal_stage do
    sequence(:name) { |n| "Stage #{n}" }
    sequence(:position) { |n| n }
    color { '#6B7280' }
    stage_type { :open }
    account
  end
end
