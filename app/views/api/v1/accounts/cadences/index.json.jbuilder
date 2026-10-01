json.array! @cadences do |cadence|
  json.partial! 'api/v1/models/cadence', formats: [:json], resource: cadence
end
