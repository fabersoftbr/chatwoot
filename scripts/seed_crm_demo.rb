# Demo data for clicking the CRM feature locally. Not loaded by db:seed.
# Run: bundle exec rails runner scripts/seed_crm_demo.rb

account = Account.find(677)
user = User.from_email('john@acme.inc')

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

deals_spec = [
  { contact_i: 0, stage_i: 0, title: 'Implantação Acme — 50 licenças', value: 1_250_000, temperature: 'hot', days: 2 },
  { contact_i: 1, stage_i: 0, title: 'Renovação anual', value: 480_000, temperature: 'warm', days: 7 },
  { contact_i: 2, stage_i: 1, title: 'Migração de PABX', value: 3_200_000, temperature: 'hot', days: 1 },
  { contact_i: 3, stage_i: 1, title: 'Piloto de atendimento', value: 150_000, temperature: 'cold', days: 14 },
  { contact_i: 4, stage_i: 1, title: 'Expansão para filial SP', value: 890_000, temperature: 'warm', days: -3 },
  { contact_i: 5, stage_i: 2, title: 'Contrato enviado — matriz', value: 5_400_000, temperature: 'hot', days: 3 },
  { contact_i: 6, stage_i: 2, title: 'Upgrade para plano Enterprise', value: 2_100_000, temperature: 'warm', days: 10 },
  { contact_i: 7, stage_i: 3, title: 'Projeto integrado WhatsApp', value: 7_800_000, temperature: 'hot', days: nil }
]

deals_spec.each do |spec|
  stage = stages[spec[:stage_i]] || stages.last
  deal = account.deals.find_or_initialize_by(title: spec[:title])
  next if deal.persisted?

  deal.assign_attributes(
    contact: contacts[spec[:contact_i]],
    deal_stage: stage,
    assignee: user,
    value_cents: spec[:value],
    currency: 'BRL',
    temperature: spec[:temperature],
    description: 'Negócio de demonstração criado para validar a tela de CRM.',
    next_action_at: spec[:days]&.days&.from_now,
    position: (spec[:contact_i] + 1) * 1000
  )
  deal.save!
  deal.deal_activities.create!(
    activity_type: 'note',
    content: 'Primeiro contato feito. Cliente pediu proposta por e-mail.',
    user: user
  )
end

puts "deals: #{account.deals.count} across #{account.deal_stages.count} stages"
account.deal_stages.order(:position).each do |s|
  puts "  #{s.name}: #{s.deals.count}"
end
