class TriggerScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Trigger the scheduled campaign jobs for 'one_off' and 'whatsapp' campaigns
    Campaign.where(campaign_type: [:one_off, :whatsapp],   # Incluindo 'whatsapp' nas campanhas
                   campaign_status: :active)
            .where(scheduled_at: 3.days.ago..Time.current)
            .find_each(batch_size: 100) do |campaign|
      Campaigns::TriggerOneoffCampaignJob.perform_later(campaign)
    end
  
    # Job to reopen snoozed conversations
    Conversations::ReopenSnoozedConversationsJob.perform_later
  
    # Job to reopen snoozed notifications
    Notification::ReopenSnoozedNotificationsJob.perform_later
  
    # Job to auto-resolve conversations
    Account::ConversationsResolutionSchedulerJob.perform_later
  
    # Job to sync whatsapp templates
    Channels::Whatsapp::TemplatesSyncSchedulerJob.perform_later
  
    # Job to clear notifications which are older than 1 month
    Notification::RemoveOldNotificationJob.perform_later
  end
  
  
end

TriggerScheduledItemsJob.prepend_mod_with('TriggerScheduledItemsJob')
