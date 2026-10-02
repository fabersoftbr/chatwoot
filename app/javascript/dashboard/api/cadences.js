/* global axios */
import ApiClient from './ApiClient';

class CadencesAPI extends ApiClient {
  constructor() {
    super('cadences', { accountScoped: true });
  }

  getEnrollments(cadenceId) {
    return axios.get(`${this.url}/${cadenceId}/enrollments`);
  }

  stopEnrollment(cadenceId, enrollmentId) {
    return axios.patch(`${this.url}/${cadenceId}/enrollments/${enrollmentId}`);
  }
}

export default new CadencesAPI();
