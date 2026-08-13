json.payload do
  json.array! @pipelines do |pipeline|
    json.partial! 'api/v1/models/pipeline', formats: [:json], pipeline: pipeline
  end
end
