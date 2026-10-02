# Stops a cadence the moment the contact answers. The step runner also checks before sending, so
# this is not what makes the guarantee — it is what spares the contact a message that was already
# due and would otherwise go out on the next tick, after they had replied.
class CadenceListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming?

    CadenceEnrollment.active
                     .where(conversation_id: message.conversation_id)
                     .find_each { |enrollment| enrollment.stopped_replied! }
  end
end
