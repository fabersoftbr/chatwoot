# A cadence is an ordered list of messages delivered to every contact in its audience, each step
# offset from the moment the contact was enrolled. It belongs to one inbox, because the channel
# decides what a step may contain: WhatsApp Cloud can only be reached with an approved template
# outside the 24h window, and a cadence is by definition outside it.
class Cadence < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true
  belongs_to :deal_stage, optional: true

  has_many :cadence_enrollments, dependent: :destroy

  validates :title, presence: true
  validate :inbox_must_be_supported
  validate :steps_must_be_present
  validate :steps_must_match_channel
  validate :steps_are_frozen_once_enrolled, on: :update

  scope :running, -> { where(enabled: true) }

  # Both scheduling modes collapse into one walk: advance the offset in days, pin the time of day
  # when the step asks for one, then roll forward to the requested weekday. Done inside the inbox
  # timezone so "Tuesday 19:00" survives DST, and always measured from `from` so a late tick never
  # accumulates drift across steps.
  def deliver_at_for(index, from:)
    step = steps[index]
    return if step.blank?

    at = from.in_time_zone(timezone).advance(days: step['delay_days'].to_i)
    at = at.change(hour: step['send_hour'].to_i, min: step['send_minute'].to_i) if step['send_hour'].present?
    7.times do
      break if step['weekday'].blank? || at.wday == step['weekday'].to_i

      at = at.advance(days: 1)
    end
    at.utc
  end

  def audience_label_titles
    account.labels.where(id: audience.select { |item| item['type'] == 'Label' }.pluck('id')).pluck(:title)
  end

  def timezone
    inbox.timezone.presence || 'UTC'
  end

  def whatsapp_cloud?
    inbox.inbox_type == 'Whatsapp'
  end

  private

  # Evolution replies leave through the api-inbox webhook and WhatsApp Cloud through
  # SendOnWhatsappService. Every other channel would silently create messages nobody delivers.
  def inbox_must_be_supported
    return if inbox.blank?
    return if %w[Whatsapp Evolution].include?(inbox.inbox_type)

    errors.add(:inbox, I18n.t('errors.cadences.unsupported_inbox'))
  end

  def steps_must_be_present
    errors.add(:steps, I18n.t('errors.cadences.no_steps')) if steps.blank?
  end

  # Catching this at save time turns a silent `failed` bubble two days later into a 422 on the form.
  def steps_must_match_channel
    return if inbox.blank? || steps.blank?

    steps.each_with_index do |step, index|
      if whatsapp_cloud?
        errors.add(:steps, I18n.t('errors.cadences.template_required', position: index + 1)) if step['template_params'].blank?
      elsif step['content'].blank?
        errors.add(:steps, I18n.t('errors.cadences.content_required', position: index + 1))
      end
    end
  end

  # Enrollments carry a step_index into this array, so editing it under them would send the wrong
  # message or walk off the end. Clone the cadence to change a live sequence.
  def steps_are_frozen_once_enrolled
    return unless steps_changed?
    return unless cadence_enrollments.active.exists?

    errors.add(:steps, I18n.t('errors.cadences.steps_locked'))
  end
end
