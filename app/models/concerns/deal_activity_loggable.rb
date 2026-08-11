module DealActivityLoggable
  extend ActiveSupport::Concern

  included do
    has_many :deal_activities, dependent: :destroy_async

    after_create_commit :log_deal_created
    after_update_commit :log_deal_changes
  end

  private

  def log_deal_created
    log_activity(:created)
  end

  def log_deal_changes
    log_stage_change if saved_change_to_deal_stage_id?
    log_temperature_change if saved_change_to_temperature?
    log_assignee_change if saved_change_to_assignee_id?
  end

  def log_stage_change
    from_stage_id, to_stage_id = saved_change_to_deal_stage_id
    log_activity(:stage_changed, metadata: { from_stage_id: from_stage_id, to_stage_id: to_stage_id })
  end

  def log_temperature_change
    from, to = saved_change_to_temperature
    log_activity(:temperature_changed, metadata: { from: from, to: to })
  end

  def log_assignee_change
    log_activity(:assigned, metadata: { to_user_id: assignee_id })
  end

  def log_activity(activity_type, metadata: {})
    deal_activities.create!(
      account_id: account_id,
      user: Current.user,
      activity_type: activity_type,
      metadata: metadata
    )
  end
end
