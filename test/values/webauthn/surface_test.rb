# typed: false
# frozen_string_literal: true

require "test_helper"

class WebauthnSurfaceTest < ActiveSupport::TestCase
  test "surface identity renders as its fixed key and resolves its ceremony model" do
    app = Webauthn::Surface.for(:app)
    org = Webauthn::Surface.for(:org)

    assert_equal "app", app.to_s
    assert_equal ClientPasskeyCeremonyTransaction, app.ceremony_transaction_class
    assert_equal "org", org.to_s
    assert_equal OperatorPasskeyCeremonyTransaction, org.ceremony_transaction_class
    assert_same app, Webauthn::Surface.for(app)
    assert_raises(Webauthn::Surface::UnknownSurfaceError) { Webauthn::Surface.for(:unknown) }
  end
end
