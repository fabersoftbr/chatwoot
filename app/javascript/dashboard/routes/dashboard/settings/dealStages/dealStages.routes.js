import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import SettingsContent from '../Wrapper.vue';
import DealStagesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/deal-stages'),
      component: SettingsContent,
      props: () => {
        return {
          headerTitle: 'CRM.SETTINGS.TITLE',
          icon: 'arrow-trending-lines',
        };
      },
      children: [
        {
          path: '',
          name: 'settings_deal_stages',
          component: DealStagesIndex,
          meta: {
            permissions: ['administrator'],
            featureFlag: FEATURE_FLAGS.DEALS,
          },
        },
      ],
    },
  ],
};
