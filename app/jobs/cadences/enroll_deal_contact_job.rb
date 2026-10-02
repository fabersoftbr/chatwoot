# Enrolls a deal's contact into whatever cadence is attached to the stage the deal just landed in.
# Enqueued rather than run inline so dragging a card across the board stays instant.
class Cadences::EnrollDealContactJob < ApplicationJob
  queue_as :low

  def perform(deal)
    deal.account.cadences.running.where(deal_stage_id: deal.deal_stage_id).find_each do |cadence|
      CadenceEnrollment.enroll(cadence, deal.contact)
    end
  end
end
