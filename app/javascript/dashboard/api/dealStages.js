/* global axios */
import ApiClient from './ApiClient';

class DealStagesAPI extends ApiClient {
  constructor() {
    super('deal_stages', { accountScoped: true });
  }

  getByPipeline(pipelineId) {
    return axios.get(this.url, { params: { pipeline_id: pipelineId } });
  }

  reorder(pipelineId, stageIds) {
    return axios.patch(`${this.url}/reorder`, {
      pipeline_id: pipelineId,
      stage_ids: stageIds,
    });
  }
}

export default new DealStagesAPI();
