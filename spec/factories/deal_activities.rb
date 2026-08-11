FactoryBot.define do
  factory :deal_activity do
    activity_type { :note }
    content { 'Ligação de acompanhamento' }
    deal
    account { deal.account }
  end
end
