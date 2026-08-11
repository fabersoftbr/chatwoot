import axios from 'axios';
import { actions } from '../../deals';
import types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
  });

  describe('#fetchBoard', () => {
    it('sends the stages and the flattened deals to the store', async () => {
      const payload = [
        {
          id: 1,
          name: 'Prospectado',
          stage_type: 'open',
          deals_count: 1,
          deals_value_cents: 10000,
          deals: [{ id: 10, title: 'Contrato', deal_stage_id: 1 }],
        },
        {
          id: 2,
          name: 'Ganho',
          stage_type: 'won',
          deals_count: 0,
          deals_value_cents: 0,
          deals: [],
        },
      ];
      axios.get.mockResolvedValue({ data: { payload } });

      await actions.fetchBoard({ commit }, {});

      expect(commit.mock.calls).toEqual([
        [types.SET_DEALS_UI_FLAG, { isFetching: true }],
        [types.SET_DEAL_STAGES, payload],
        [types.SET_DEALS, [{ id: 10, title: 'Contrato', deal_stage_id: 1 }]],
        [types.SET_DEALS_UI_FLAG, { isFetching: false }],
      ]);
    });

    it('clears the flag when the request fails', async () => {
      axios.get.mockRejectedValue({ message: 'boom' });

      await expect(actions.fetchBoard({ commit }, {})).rejects.toThrow(Error);

      expect(commit.mock.calls).toEqual([
        [types.SET_DEALS_UI_FLAG, { isFetching: true }],
        [types.SET_DEALS_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#move', () => {
    it('commits the deal returned by the server', async () => {
      const deal = { id: 10, deal_stage_id: 2, position: 0 };
      axios.patch.mockResolvedValue({ data: deal });

      await actions.move({ commit }, { id: 10, stageId: 2, position: 0 });

      expect(commit.mock.calls).toEqual([
        [types.SET_DEALS_UI_FLAG, { isUpdating: true }],
        [types.EDIT_DEAL, deal],
        [types.SET_DEALS_UI_FLAG, { isUpdating: false }],
      ]);
    });
  });

  describe('#create', () => {
    it('adds the created deal', async () => {
      const deal = { id: 11, title: 'Upsell' };
      axios.post.mockResolvedValue({ data: deal });

      await actions.create({ commit }, { title: 'Upsell' });

      expect(commit.mock.calls).toEqual([
        [types.SET_DEALS_UI_FLAG, { isCreating: true }],
        [types.ADD_DEAL, deal],
        [types.SET_DEALS_UI_FLAG, { isCreating: false }],
      ]);
    });
  });
});
