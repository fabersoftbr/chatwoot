json.id resource.id
json.title resource.title
json.account_id resource.account_id
json.enabled resource.enabled
json.deal_stage_id resource.deal_stage_id
json.audience resource.audience
json.steps resource.steps
json.inbox do
  json.partial! 'api/v1/models/inbox', formats: [:json], resource: resource.inbox
end
json.sender do
  json.partial! 'api/v1/models/agent', formats: [:json], resource: resource.sender if resource.sender.present?
end
json.enrollment_counts resource.cadence_enrollments.group(:status).count
json.created_at resource.created_at
json.updated_at resource.updated_at
