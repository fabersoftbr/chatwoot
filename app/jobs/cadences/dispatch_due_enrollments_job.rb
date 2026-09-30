# The five-minute tick: top up the audience of every enabled cadence, then hand each due enrollment
# to its own job. No floor on deliver_at — an enrollment that came due while the worker was down is
# still owed its message, and the campaign poller's `3.days.ago..` floor is a silent-loss bug we are
# not copying.
class Cadences::DispatchDueEnrollmentsJob < ApplicationJob
  queue_as :low

  def perform
    Cadence.running.find_each { |cadence| Cadences::EnrollAudienceJob.perform_later(cadence) }

    CadenceEnrollment.due
                     .joins(:cadence).merge(Cadence.running)
                     .order(:deliver_at)
                     .limit(Limits::CADENCE_STEPS_PER_TICK)
                     .each { |enrollment| Cadences::DeliverStepJob.perform_later(enrollment) }
  end
end
