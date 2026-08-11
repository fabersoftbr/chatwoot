/* global axios */
import ApiClient from '../ApiClient';

class WhatsappTemplates extends ApiClient {
  constructor() {
    super('channels/whatsapp_templates', { accountScoped: true });
  }

  remove({ inboxId, name }) {
    return axios.delete(`${this.url}/${name}`, {
      params: { inbox_id: inboxId },
    });
  }
}

export default new WhatsappTemplates();
