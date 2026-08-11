import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import DealsBoardPage from './pages/DealsBoardPage.vue';

const crmRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/crm'),
      name: 'deals_board',
      component: DealsBoardPage,
      meta: {
        permissions: ['administrator', 'agent'],
        featureFlag: FEATURE_FLAGS.DEALS,
      },
    },
  ],
};

export default crmRoutes;
