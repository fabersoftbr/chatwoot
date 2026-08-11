/* global axios */
import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  board(params = {}) {
    return axios.get(`${this.url}/board`, { params });
  }

  move(id, { stageId, position, lostReason }) {
    return axios.patch(`${this.url}/${id}/move`, {
      stage_id: stageId,
      position,
      lost_reason: lostReason,
    });
  }

  getActivities(dealId) {
    return axios.get(`${this.url}/${dealId}/activities`);
  }

  createActivity(dealId, { activityType, content }) {
    return axios.post(`${this.url}/${dealId}/activities`, {
      activity_type: activityType,
      content,
    });
  }

  getByContact(contactId) {
    return axios.get(`${this.baseUrl()}/contacts/${contactId}/deals`);
  }
}

export default new DealsAPI();
