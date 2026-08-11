FactoryBot.define do
  factory :deal do
    sequence(:title) { |n| "Deal #{n}" }
    value_cents { 100_000 }
    currency { 'BRL' }
    temperature { :warm }
    account
    contact { association :contact, account: account }
    deal_stage { association :deal_stage, account: account }
  end
end
