import ApiClient from './ApiClient';

class CadencesAPI extends ApiClient {
  constructor() {
    super('cadences', { accountScoped: true });
  }
}

export default new CadencesAPI();
