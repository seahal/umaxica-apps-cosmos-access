# typed: false
# frozen_string_literal: true

# Visa logout supplies an established OP root; external actor models are not reconstructed.
# The includer supplies reset_session and session.
module AuthenticationLogoutable
  extend ActiveSupport::Concern

  private

  def reset_session_and_clear_inertia_history!
    reset_session
    session[:inertia_clear_history] = true
  end

  def record_logout_audit(root)
    case root
    when ClientToken
      AuthenticationAuditWriter.write_reference(
        ClientChronicle, ClientChronicleEvent::LOGGED_OUT,
        subject_type: "Client", subject_id: root.subject_public_id,
        actor_type: "Client", actor_id: root.subject_public_id,
      )
    when OperatorToken
      AuthenticationAuditWriter.write_reference(
        OperatorChronicle, OperatorChronicleEvent::LOGGED_OUT,
        subject_type: "Operator", subject_id: root.subject_public_id,
        actor_type: "Operator", actor_id: root.subject_public_id,
      )
    else
      raise ArgumentError, "logout audit requires an OP root session"
    end
  end
end
