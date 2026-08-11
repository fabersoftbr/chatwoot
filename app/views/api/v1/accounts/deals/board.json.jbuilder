json.payload do
  json.array! @deal_stages do |stage|
    json.partial! 'api/v1/models/deal_stage', formats: [:json], deal_stage: stage
    json.deals_count @counts[stage.id].to_i
    json.deals_value_cents @sums[stage.id].to_i
    json.deals do
      json.array! @deals_by_stage[stage] do |deal|
        json.partial! 'api/v1/models/deal', formats: [:json], deal: deal
      end
    end
  end
end
