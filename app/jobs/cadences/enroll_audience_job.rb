# Enrolls every contact carrying one of the cadence's labels. Runs on every tick rather than off a
# label-added callback because there is no such callback: Labelable#add_labels has none, and
# DataImportJob inserts taggings straight through Tagging.import, so a callback would miss exactly
# the bulk population a cadence targets. The unique index on [cadence_id, contact_id] makes the
# repeated scan free.
class Cadences::EnrollAudienceJob < ApplicationJob
  queue_as :low

  def perform(cadence)
    titles = cadence.audience_label_titles
    return if titles.blank?

    cadence.account.contacts.tagged_with(titles, any: true).where.not(phone_number: [nil, '']).find_each do |contact|
      enroll(cadence, contact)
    end
  end

  private

  def enroll(cadence, contact)
    now = Time.current
    cadence.cadence_enrollments.create!(
      account_id: cadence.account_id,
      contact: contact,
      deliver_at: cadence.deliver_at_for(0, from: now)
    )
  rescue ActiveRecord::RecordNotUnique
    # Already enrolled, including contacts that finished or replied — they never come back.
    nil
  end
end
