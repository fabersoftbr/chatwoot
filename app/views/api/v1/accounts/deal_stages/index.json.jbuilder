json.payload do
  json.array! @deal_stages do |deal_stage|
    json.partial! 'api/v1/models/deal_stage', formats: [:json], deal_stage: deal_stage
  end
end
