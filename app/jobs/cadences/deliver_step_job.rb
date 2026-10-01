class Cadences::DeliverStepJob < ApplicationJob
  queue_as :low

  def perform(enrollment)
    return enrollment.stopped_replied! if enrollment.active? && enrollment.replied?

    # Claim before sending: Sidekiq retries this job, and a retry after a successful send would
    # charge for the same message again.
    # ponytail: a crash between the claim and the send drops that step; the inverse pays twice.
    step = enrollment.claim_next_step!
    return if step.blank?

    Cadences::SendStepService.new(enrollment: enrollment, step: step).perform
  end
end
