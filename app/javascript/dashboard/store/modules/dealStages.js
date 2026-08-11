import types from '../mutation-types';
import DealStagesAPI from '../../api/dealStages';
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
  getStages: $state =>
    [...$state.records].sort((a, b) => a.position - b.position),
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_DEAL_STAGES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await DealStagesAPI.get();
      commit(types.SET_DEAL_STAGES_LIST, data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_STAGES_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit, dispatch }, stage) => {
    commit(types.SET_DEAL_STAGES_UI_FLAG, { isCreating: true });
    try {
      await DealStagesAPI.create(stage);
      await dispatch('get');
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_STAGES_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit, dispatch }, { id, ...stage }) => {
    commit(types.SET_DEAL_STAGES_UI_FLAG, { isUpdating: true });
    try {
      await DealStagesAPI.update(id, stage);
      await dispatch('get');
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_STAGES_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit, dispatch }, id) => {
    commit(types.SET_DEAL_STAGES_UI_FLAG, { isDeleting: true });
    try {
      await DealStagesAPI.delete(id);
      await dispatch('get');
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_STAGES_UI_FLAG, { isDeleting: false });
    }
  },

  reorder: async ({ commit }, stageIds) => {
    commit(types.SET_DEAL_STAGES_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await DealStagesAPI.reorder(stageIds);
      commit(types.SET_DEAL_STAGES_LIST, data.payload);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEAL_STAGES_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_DEAL_STAGES_UI_FLAG]($state, uiFlags) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlags };
  },
  [types.SET_DEAL_STAGES_LIST]($state, records) {
    $state.records = records;
  },
};

export default { namespaced: true, state, getters, actions, mutations };
