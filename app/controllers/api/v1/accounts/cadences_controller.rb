class Api::V1::Accounts::CadencesController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :cadence, except: [:index, :create]
  before_action :check_authorization

  def index
    @cadences = Current.account.cadences
  end

  def show; end

  def create
    @cadence = Current.account.cadences.create!(cadence_params)
  end

  def update
    @cadence.update!(cadence_params)
  end

  def destroy
    @cadence.destroy!
    head :ok
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?(:cadences)
  end

  def cadence
    @cadence ||= Current.account.cadences.find(params[:id])
  end

  def cadence_params
    params.require(:cadence).permit(
      :title, :enabled, :inbox_id, :sender_id, :deal_stage_id,
      audience: [:type, :id],
      steps: [:delay_days, :send_hour, :send_minute, :weekday, :content, { template_params: {} }]
    )
  end
end
