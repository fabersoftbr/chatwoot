# One contact walking through one cadence. `step_index` is both the cursor and the claim: advancing
# it under a lock is what stops a Sidekiq retry from paying for the same send twice.
class CadenceEnrollment < ApplicationRecord
  belongs_to :account
  belongs_to :cadence
  belongs_to :contact
  belongs_to :conversation, optional: true

  enum status: { active: 0, completed: 1, stopped_replied: 2, stopped_manually: 3 }

  scope :due, -> { active.where(deliver_at: ..Time.current) }

  # Returns the step that was claimed, or nil when there is nothing left to send. The caller sends
  # only on a non-nil return, so a second worker on the same record walks away empty-handed.
  def claim_next_step!
    with_lock do
      return unless active? && deliver_at <= Time.current

      step = cadence.steps[step_index]
      return if step.blank?

      advance!
      step
    end
  end

  def replied?
    return false if conversation.blank?

    conversation.messages.incoming.where('messages.created_at > ?', created_at).exists?
  end

  private

  def advance!
    next_index = step_index + 1
    next_at = cadence.deliver_at_for(next_index, from: created_at)

    if next_at.blank?
      update!(step_index: next_index, status: :completed)
    else
      update!(step_index: next_index, deliver_at: next_at)
    end
  end
end
