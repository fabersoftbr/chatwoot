json.id deal.id
json.title deal.title
json.description deal.description
json.value_cents deal.value_cents
json.currency deal.currency
json.temperature deal.temperature
json.position deal.position
json.deal_stage_id deal.deal_stage_id
json.expected_close_on deal.expected_close_on
json.next_action deal.next_action
json.next_action_at deal.next_action_at
json.closed_at deal.closed_at
json.lost_reason deal.lost_reason
json.created_at deal.created_at

json.contact do
  json.id deal.contact.id
  json.name deal.contact.name
  json.email deal.contact.email
  json.phone_number deal.contact.phone_number
  json.thumbnail deal.contact.avatar_url
end

json.assignee_id deal.assignee_id

if deal.assignee.present?
  json.assignee do
    json.id deal.assignee.id
    json.name deal.assignee.name
    json.thumbnail deal.assignee.avatar_url
  end
else
  json.assignee nil
end
