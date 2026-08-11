import types from '../mutation-types';
import DealsAPI from '../../api/deals';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  stages: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getDeals: $state => $state.records,
  getDeal: $state => id =>
    $state.records.find(record => record.id === Number(id)),
  getStages: $state => $state.stages,
  getDealsByStage: $state => stageId =>
    $state.records
      .filter(record => record.deal_stage_id === stageId)
      .sort((a, b) => a.position - b.position),
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  fetchBoard: async ({ commit }, params) => {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await DealsAPI.board(params);
      commit(types.SET_DEAL_STAGES, data.payload);
      commit(
        types.SET_DEALS,
        data.payload.flatMap(stage => stage.deals)
      );
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  show: async ({ commit }, id) => {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await DealsAPI.show(id);
      commit(types.EDIT_DEAL, data);
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  fetchByContact: async ({ commit }, contactId) => {
    commit(types.SET_DEALS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await DealsAPI.getByContact(contactId);
      return data.payload;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, dealObj) => {
    commit(types.SET_DEALS_UI_FLAG, { isCreating: true });
    try {
      const { data } = await DealsAPI.create(dealObj);
      commit(types.ADD_DEAL, data);
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...dealObj }) => {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await DealsAPI.update(id, dealObj);
      commit(types.EDIT_DEAL, data);
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  move: async ({ commit }, { id, stageId, position, lostReason }) => {
    commit(types.SET_DEALS_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await DealsAPI.move(id, {
        stageId,
        position,
        lostReason,
      });
      commit(types.EDIT_DEAL, data);
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isUpdating: false });
    }
  },

  fetchActivities: async (_, dealId) => {
    try {
      const { data } = await DealsAPI.getActivities(dealId);
      return data.payload;
    } catch (error) {
      return throwErrorMessage(error);
    }
  },

  createActivity: async (_, { dealId, activityType, content }) => {
    try {
      const { data } = await DealsAPI.createActivity(dealId, {
        activityType,
        content,
      });
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_DEALS_UI_FLAG, { isDeleting: true });
    try {
      await DealsAPI.delete(id);
      commit(types.DELETE_DEAL, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_DEALS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_DEALS_UI_FLAG]($state, uiFlags) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlags };
  },
  [types.SET_DEALS]($state, records) {
    $state.records = records;
  },
  [types.SET_DEAL_STAGES]($state, stages) {
    $state.stages = stages.map(({ deals, ...stage }) => stage);
  },
  [types.ADD_DEAL]($state, deal) {
    $state.records.push(deal);
  },
  [types.EDIT_DEAL]($state, deal) {
    const index = $state.records.findIndex(record => record.id === deal.id);
    if (index > -1) $state.records.splice(index, 1, deal);
    else $state.records.push(deal);
  },
  [types.DELETE_DEAL]($state, id) {
    $state.records = $state.records.filter(record => record.id !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
