/* global axios */
import ApiClient from './ApiClient';

class DealStagesAPI extends ApiClient {
  constructor() {
    super('deal_stages', { accountScoped: true });
  }

  reorder(stageIds) {
    return axios.patch(`${this.url}/reorder`, { stage_ids: stageIds });
  }
}

export default new DealStagesAPI();
