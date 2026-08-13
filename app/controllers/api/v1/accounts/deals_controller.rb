class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :fetch_deal, only: [:show, :update, :destroy, :move]
  before_action :check_authorization

  def index
    @deals = filtered_deals.page(params[:page]).per(RESULTS_PER_PAGE)
  end

  def board
    @deal_stages = Pipeline.resolve(Current.account, params[:pipeline_id]).deal_stages.ordered
    stage_deals = filtered_deals(Current.account.deals.where(deal_stage_id: @deal_stages.map(&:id)))

    @counts = stage_deals.unscope(:order).group(:deal_stage_id).count
    @sums = stage_deals.unscope(:order).group(:deal_stage_id).sum(:value_cents)
    @deals_by_stage = @deal_stages.index_with do |stage|
      stage_deals.where(deal_stage_id: stage.id).limit(RESULTS_PER_PAGE)
    end
  end

  def show; end

  def create
    @deal = Current.account.deals.create!(permitted_params)
    render :show
  end

  def update
    @deal.update!(permitted_params)
    render :show
  end

  def move
    @deal.move_to!(
      stage_id: params.require(:stage_id),
      position: params.fetch(:position, 0),
      lost_reason: params[:lost_reason]
    )
    render :show
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  private

  # rubocop:disable Metrics/AbcSize
  def filtered_deals(scope = Current.account.deals)
    deals = scope.includes(:deal_stage, contact: { avatar_attachment: [:blob] }, assignee: { avatar_attachment: [:blob] }).ordered
    deals = deals.where(deal_stage_id: params[:stage_id]) if params[:stage_id].present? && action_name != 'board'
    deals = deals.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    deals = deals.where(temperature: params[:temperature]) if params[:temperature].present?
    deals = deals.overdue if ActiveModel::Type::Boolean.new.cast(params[:overdue])
    deals = search(deals) if params[:q].present?
    deals
  end
  # rubocop:enable Metrics/AbcSize

  def search(deals)
    term = "%#{params[:q].downcase}%"
    deals.left_joins(:contact).where(
      'LOWER(deals.title) LIKE :term OR LOWER(contacts.name) LIKE :term', term: term
    )
  end

  def fetch_deal
    @deal = Current.account.deals.find(params[:id])
  end

  def check_authorization
    authorize(@deal || Deal)
  end

  def permitted_params
    params.permit(
      :title, :description, :contact_id, :deal_stage_id, :assignee_id,
      :value_cents, :currency, :temperature, :expected_close_on,
      :next_action_at, :next_action, :lost_reason
    )
  end
end
