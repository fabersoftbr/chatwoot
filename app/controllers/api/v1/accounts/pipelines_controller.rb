class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:update, :destroy]
  before_action :check_authorization

  def index
    Pipeline.seed_default(Current.account)
    @pipelines = Current.account.pipelines.ordered
  end

  def create
    @pipeline = Current.account.pipelines.create!(permitted_params)
    render :show
  end

  def update
    @pipeline.update!(permitted_params)
    render :show
  end

  def destroy
    deals_count = Current.account.deals.where(deal_stage_id: @pipeline.deal_stages.select(:id)).count
    if deals_count.positive?
      render json: { error: I18n.t('errors.pipelines.has_deals'), deals_count: deals_count },
             status: :unprocessable_entity
      return
    end

    @pipeline.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def check_authorization
    authorize(@pipeline || Pipeline)
  end

  def permitted_params
    params.permit(:name, :position)
  end
end
