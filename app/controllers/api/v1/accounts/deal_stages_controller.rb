class Api::V1::Accounts::DealStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_deal_stage, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @deal_stages = DealStage.seed_defaults(Current.account)
  end

  def show; end

  def create
    @deal_stage = Current.account.deal_stages.create!(permitted_params)
    render :show
  end

  def update
    @deal_stage.update!(permitted_params)
    render :show
  end

  def destroy
    deals_count = @deal_stage.deals.count
    if deals_count.positive?
      render json: { error: I18n.t('errors.deal_stages.has_deals'), deals_count: deals_count },
             status: :unprocessable_entity
      return
    end

    @deal_stage.destroy!
    head :ok
  end

  def reorder
    Current.account.deal_stages.where(id: params[:stage_ids]).find_each do |stage|
      # rubocop:disable Rails/SkipsModelValidations
      stage.update_column(:position, params[:stage_ids].map(&:to_i).index(stage.id))
      # rubocop:enable Rails/SkipsModelValidations
    end

    @deal_stages = Current.account.deal_stages.ordered
    render :index
  end

  private

  def fetch_deal_stage
    @deal_stage = Current.account.deal_stages.find(params[:id])
  end

  def check_authorization
    authorize(@deal_stage || DealStage)
  end

  def permitted_params
    params.permit(:name, :color, :position, :stage_type)
  end
end
