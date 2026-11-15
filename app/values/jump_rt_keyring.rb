# typed: false
# frozen_string_literal: true

require "jit_security_jwt_key_material"
require "jit_security_jwt_registry"

module JumpRtKeyring
  module_function

  def active_kid(namespace)
    JitSecurityJwtRegistry.surface(namespace).current_kid
  end

  def private_key(namespace)
    issuer = JitSecurityJwtRegistry.surface(namespace)
    JitSecurityJwtRegistry.private_key_for(issuer.id, issuer.current_kid)
  end

  def decode_private_key(value)
    JitSecurityJwtKeyMaterial.decode_private_key(value)
  rescue JitSecurityJwtKeyMaterial::Error
    nil
  end
end
