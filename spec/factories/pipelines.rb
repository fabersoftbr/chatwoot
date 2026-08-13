FactoryBot.define do
  factory :pipeline do
    sequence(:name) { |n| "Pipeline #{n}" }
    sequence(:position) { |n| n }
    account
  end
end
