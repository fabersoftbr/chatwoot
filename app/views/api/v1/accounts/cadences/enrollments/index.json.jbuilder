json.array! @enrollments do |enrollment|
  json.id enrollment.id
  json.status enrollment.status
  json.step_index enrollment.step_index
  json.deliver_at enrollment.deliver_at
  json.conversation_id enrollment.conversation_id
  json.contact do
    json.id enrollment.contact.id
    json.name enrollment.contact.name
    json.phone_number enrollment.contact.phone_number
  end
end
