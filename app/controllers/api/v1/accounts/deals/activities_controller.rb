class Api::V1::Accounts::Deals::ActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_deal
  before_action :check_authorization

  def index
    @activities = @deal.deal_activities.includes(:user).latest
  end

  def create
    unless DealActivity::MANUAL_TYPES.include?(params[:activity_type])
      render json: { error: I18n.t('errors.deal_activities.invalid_type') }, status: :unprocessable_entity
      return
    end

    @activity = @deal.deal_activities.create!(
      account_id: @deal.account_id,
      user: Current.user,
      activity_type: params[:activity_type],
      content: params[:content]
    )
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:deal_id])
  end

  def check_authorization
    authorize(@deal)
  end
end
