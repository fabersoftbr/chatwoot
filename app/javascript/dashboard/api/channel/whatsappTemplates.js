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

  // hsmId is the template's Meta id. Without it Meta deletes every language
  // version sharing this name, so always send it when the synced payload has one.
  delete(inboxId, name, hsmId) {
    return axios.delete(`${this.url}/${inboxId}/whatsapp_templates/${name}`, {
      params: hsmId ? { hsm_id: hsmId } : {},
    });
  }
}

export default new WhatsappTemplates();
