import { frontendURL } from '../../../../helper/URLHelper';

const campaigns = accountId => ({
  parentNav: 'campaigns',
  routes: [
    'campaigns_sms_index',
    'campaigns_livechat_index',
    'campaigns_whatsapp_index',
  ], // Adicione a nova rota
  menuItems: [
    {
      icon: 'arrow-swap',
      label: 'LIVE_CHAT',
      key: 'ongoingCampaigns',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/live_chat`),
      toStateName: 'campaigns_livechat_index',
    },
    {
      key: 'oneOffCampaigns',
      icon: 'sound-source',
      label: 'SMS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/sms`),
      toStateName: 'campaigns_sms_index',
    },
    {
      key: 'whatsappCampaigns',
      icon: 'message-circle', // Escolha o ícone apropriado
      label: 'WHATSAPP', // Use a chave de tradução correspondente
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/whatsapp`),
      toStateName: 'campaigns_Whatsapp_index',
    },
  ],
});

export default campaigns;
