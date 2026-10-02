import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import CadencesAPI from '../../api/cadences';

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
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCadences(_state) {
    return [..._state.records].sort((a, b) => a.id - b.id);
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_CADENCE_UI_FLAG, { isFetching: true });
    try {
      const response = await CadencesAPI.get();
      commit(types.SET_CADENCES, response.data);
    } finally {
      commit(types.SET_CADENCE_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, cadence) => {
    commit(types.SET_CADENCE_UI_FLAG, { isCreating: true });
    try {
      const response = await CadencesAPI.create(cadence);
      commit(types.ADD_CADENCE, response.data);
      return response.data;
    } finally {
      commit(types.SET_CADENCE_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...cadence }) => {
    commit(types.SET_CADENCE_UI_FLAG, { isUpdating: true });
    try {
      const response = await CadencesAPI.update(id, cadence);
      commit(types.EDIT_CADENCE, response.data);
      return response.data;
    } finally {
      commit(types.SET_CADENCE_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_CADENCE_UI_FLAG, { isDeleting: true });
    try {
      await CadencesAPI.delete(id);
      commit(types.DELETE_CADENCE, id);
    } finally {
      commit(types.SET_CADENCE_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CADENCE_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_CADENCES]: MutationHelpers.set,
  [types.ADD_CADENCE]: MutationHelpers.create,
  [types.EDIT_CADENCE]: MutationHelpers.update,
  [types.DELETE_CADENCE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
