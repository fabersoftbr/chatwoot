json.payload do
  json.array! @activities do |activity|
    json.partial! 'api/v1/models/deal_activity', formats: [:json], deal_activity: activity
  end
end
