json.id deal_activity.id
json.activity_type deal_activity.activity_type
json.content deal_activity.content
json.metadata deal_activity.metadata
json.created_at deal_activity.created_at

if deal_activity.user.present?
  json.user do
    json.id deal_activity.user.id
    json.name deal_activity.user.name
    json.thumbnail deal_activity.user.avatar_url
  end
else
  json.user nil
end
