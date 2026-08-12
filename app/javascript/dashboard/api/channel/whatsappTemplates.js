/* global axios */
import ApiClient from '../ApiClient';

// Templates are nested under an inbox because every call writes to that
// inbox's Meta WABA, and the controller authorizes on the inbox.
class WhatsappTemplates extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  create(inboxId, payload) {
    return axios.post(`${this.url}/${inboxId}/whatsapp_templates`, payload);
  }

  delete(inboxId, name) {
    return axios.delete(`${this.url}/${inboxId}/whatsapp_templates/${name}`);
  }
}

export default new WhatsappTemplates();
