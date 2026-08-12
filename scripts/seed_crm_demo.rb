# Demo data for clicking the CRM feature locally. Not loaded by db:seed.
# Run: bundle exec rails runner scripts/seed_crm_demo.rb

account = Account.find(677)
user = User.find_by(email: 'john@acme.inc')

account.enable_features('deals')
account.save!
puts "deals flag: #{account.feature_enabled?('deals')}"

DealStage.seed_defaults(account)
stages = account.deal_stages.order(:position).to_a
puts "stages: #{stages.map(&:name).join(', ')}"

names = ['Ana Ribeiro', 'Bruno Cardoso', 'Carla Menezes', 'Diego Farias',
         'Elisa Tavares', 'Fábio Nogueira', 'Gabriela Pinto', 'Henrique Sá']
contacts = names.map.with_index do |name, i|
  account.contacts.find_or_create_by!(email: "#{name.parameterize}@example.com") do |c|
    c.name = name
    c.phone_number = format('+55119%08d', 10_000_000 + i)
  end
end

temperatures = %w[hot warm cold]
deals_spec = [
  # [contact index, stage index, title, value in cents, temperature, next_action_days]
  [0, 0, 'Implantação Acme — 50 licenças',        1_250_000, 'hot',  2],
  [1, 0, 'Renovação anual',                         480_000, 'warm', 7],
  [2, 1, 'Migração de PABX',                      3_200_000, 'hot',  1],
  [3, 1, 'Piloto de atendimento',                   150_000, 'cold', 14],
  [4, 1, 'Expansão para filial SP',                 890_000, 'warm', -3],
  [5, 2, 'Contrato enviado — matriz',             5_400_000, 'hot',  3],
  [6, 2, 'Upgrade para plano Enterprise',         2_100_000, 'warm', 10],
  [7, 3, 'Projeto integrado WhatsApp',            7_800_000, 'hot',  nil]
]

deals_spec.each do |contact_i, stage_i, title, value, temperature, days|
  stage = stages[stage_i] || stages.last
  deal = account.deals.find_or_initialize_by(title: title)
  next if deal.persisted?

  deal.assign_attributes(
    contact: contacts[contact_i],
    deal_stage: stage,
    assignee: user,
    value_cents: value,
    currency: 'BRL',
    temperature: temperature,
    description: "Negócio de demonstração criado para validar a tela de CRM.",
    next_action_at: days ? days.days.from_now : nil,
    position: (contact_i + 1) * 1000
  )
  deal.save!
  deal.deal_activities.create!(
    activity_type: 'note',
    content: "Primeiro contato feito. Cliente pediu proposta por e-mail.",
    user: user
  )
end

puts "deals: #{account.deals.count} across #{account.deal_stages.count} stages"
account.deal_stages.order(:position).each do |s|
  puts "  #{s.name}: #{s.deals.count}"
end
