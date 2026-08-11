# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DealPolicy, type: :policy do
  subject(:deal_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:deal) { create(:deal, account: account) }

  let(:administrator_context) do
    { user: administrator, account: account, account_user: account.account_users.find_by(user_id: administrator.id) }
  end
  let(:agent_context) do
    { user: agent, account: account, account_user: account.account_users.find_by(user_id: agent.id) }
  end

  permissions :index?, :show?, :create?, :update?, :move?, :board? do
    context 'when administrator' do
      it { expect(deal_policy).to permit(administrator_context, deal) }
    end

    context 'when agent' do
      it { expect(deal_policy).to permit(agent_context, deal) }
    end
  end

  permissions :destroy? do
    context 'when administrator' do
      it { expect(deal_policy).to permit(administrator_context, deal) }
    end

    context 'when agent' do
      it { expect(deal_policy).not_to permit(agent_context, deal) }
    end
  end
end
