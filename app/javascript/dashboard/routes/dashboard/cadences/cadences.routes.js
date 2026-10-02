import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import CadencesPage from './pages/CadencesPage.vue';

const cadencesRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/cadences'),
      name: 'cadences_index',
      meta: {
        featureFlag: FEATURE_FLAGS.CADENCES,
        permissions: ['administrator'],
      },
      component: CadencesPage,
    },
  ],
};

export default cadencesRoutes;
