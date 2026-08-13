import types from '../mutation-types';
import PipelinesAPI from '../../api/pipelines';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getPipelines: $state =>
    [...$state.records].sort((a, b) => a.position - b.position),
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_PIPELINES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await PipelinesAPI.get();
      commit(types.SET_PIPELINES_LIST, data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit, dispatch }, pipeline) => {
    commit(types.SET_PIPELINES_UI_FLAG, { isCreating: true });
    try {
      const { data } = await PipelinesAPI.create(pipeline);
      await dispatch('get');
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit, dispatch }, { id, ...pipeline }) => {
    commit(types.SET_PIPELINES_UI_FLAG, { isUpdating: true });
    try {
      await PipelinesAPI.update(id, pipeline);
      await dispatch('get');
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit, dispatch }, id) => {
    commit(types.SET_PIPELINES_UI_FLAG, { isDeleting: true });
    try {
      await PipelinesAPI.delete(id);
      await dispatch('get');
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_PIPELINES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_PIPELINES_UI_FLAG]($state, uiFlags) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlags };
  },
  [types.SET_PIPELINES_LIST]($state, records) {
    $state.records = records;
  },
};

export default { namespaced: true, state, getters, actions, mutations };
