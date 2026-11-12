# frozen_string_literal: true

namespace :org_telephone_public_ids do
  desc "Report live legacy ORG Telephone ceremony and receipt counts without modifying proof"
  task legacy_references: :environment do
    puts OperatorTelephoneLegacyReferenceInventory.call(
      scope: OperatorTelephoneCeremonyTransaction.all,
    ).to_json
  end
end
