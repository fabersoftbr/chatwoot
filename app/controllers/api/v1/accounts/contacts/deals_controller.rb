class Api::V1::Accounts::Contacts::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_contact
  before_action :check_authorization

  def index
    @deals = @contact.deals.includes(:contact, :assignee).ordered
  end

  private

  def fetch_contact
    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def check_authorization
    authorize(Deal)
  end
end
