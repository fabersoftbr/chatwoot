class Api::V1::Accounts::Cadences::EnrollmentsController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :cadence
  before_action :check_authorization

  def index
    @enrollments = @cadence.cadence_enrollments.includes(:contact).order(:deliver_at, :id)
  end

  # Stopping is one-way on purpose: the unique index means a contact never re-enters, so there is
  # no resume to offer. Duplicate the cadence to start someone over.
  def update
    @enrollment = @cadence.cadence_enrollments.find(params[:id])
    @enrollment.stopped_manually!
    render json: { id: @enrollment.id, status: @enrollment.status }
  end

  private

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?(:cadences)
  end

  def cadence
    @cadence ||= Current.account.cadences.find(params[:cadence_id])
  end

  def check_authorization
    authorize(@cadence)
  end
end
