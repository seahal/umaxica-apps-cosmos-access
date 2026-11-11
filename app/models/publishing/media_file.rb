# frozen_string_literal: true

module Publishing
  class MediaFile < PublishingRecord
    self.table_name = "publishing_media_files"

    # FIXME: Shared PublicId permits 25 characters while chk_media_files_pid requires exactly 21;
    # remediation D2a preserves the DB contract until a separate identifier decision reconciles them.
    include PublicId

    validates :storage_key, uniqueness: true, on: :create
    validates :byte_size, :content_type, :digest, :digest_algorithm, :storage_key, exclusion: { in: [nil] }
  end
end
