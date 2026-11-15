# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_oauth_callback_states
# Database name: op_base_app
#
#  id           :bigint           not null, primary key
#  consumed_at  :datetime
#  expires_at   :datetime         not null
#  intent       :string
#  issued_at    :datetime         not null
#  provider     :string           not null
#  state_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_client_oauth_callback_states_on_expires_at    (expires_at)
#  index_client_oauth_callback_states_on_state_digest  (state_digest) UNIQUE
#
class ClientOauthCallbackState < OpBaseAppRecord
  include OauthCallbackStateable

  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
  scope :unconsumed, -> { where(consumed_at: nil) }

  validates :state_digest, :provider, :issued_at, :expires_at, presence: true
  validates :state_digest, uniqueness: true
end
