import axios from 'axios';
import { actions } from '../../pipelines';
import types from '../../../mutation-types';

const commit = vi.fn();
const dispatch = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
  });

  describe('#get', () => {
    it('commits the payload on success', async () => {
      axios.get.mockResolvedValue({
        data: { payload: [{ id: 1, name: 'Funil padrão' }] },
      });

      await actions.get({ commit });

      expect(commit.mock.calls).toEqual([
        [types.SET_PIPELINES_UI_FLAG, { isFetching: true }],
        [types.SET_PIPELINES_LIST, [{ id: 1, name: 'Funil padrão' }]],
        [types.SET_PIPELINES_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#create', () => {
    it('refetches the list after creating', async () => {
      axios.post.mockResolvedValue({ data: { id: 2, name: 'Outbound' } });

      await actions.create({ commit, dispatch }, { name: 'Outbound' });

      expect(dispatch).toHaveBeenCalledWith('get');
    });
  });
});
