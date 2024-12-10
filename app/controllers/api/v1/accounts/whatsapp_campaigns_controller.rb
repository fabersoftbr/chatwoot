class Api::V1::Accounts::WhatsappCampaignsController < ApplicationController
    before_action :set_account
  
    def index
      whatsapp_campaigns = @account.campaigns.where(campaign_type: 'whatsapp')
      render json: whatsapp_campaigns
    end
  
    private
  
    def set_account
      @account = Account.find(params[:account_id])
    end
  end
  