# typed: false
# frozen_string_literal: true

require "test_helper"

# Source-level guard for the brand title contract. The rendered contract lives in
# HtmlTitleContractTest; this test keeps the layouts themselves from drifting back
# to a surface-flavoured site title or to a hand-rolled title abstraction.
class LayoutTitleContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CANONICAL_LAYOUTS = {
    "app/views/layouts/auth/app/application.html.erb" => "APP",
    "app/views/layouts/auth/org/application.html.erb" => "ORG",
    "app/views/layouts/visa/app/application.html.erb" => "VISA APP",
    "app/views/layouts/visa/org/application.html.erb" => "VISA ORG",
  }.freeze

  # Routing and deployment vocabulary. None of it is brand vocabulary, so none of
  # it may appear in the site title.
  FORBIDDEN_SITE_WORDS = %w(Auth Base Core Warp Palm Jump Global Rails Inertia API).freeze

  test "canonical layouts hand the brand contract to meta-tags" do
    CANONICAL_LAYOUTS.each do |path, tld|
      contents = Rails.root.join(path).read

      assert_predicate Rails.root.join(path), :exist?
      assert_includes contents, %(site: "\#{ENV.fetch("BRAND_NAME").upcase} (#{tld})"),
                      "missing the brand site title in #{path}"
      assert_includes contents, %(separator: "—"), "missing the EM DASH separator in #{path}"
      assert_includes contents, "reverse: true",
                      "#{path} must set reverse: true, otherwise meta-tags emits SITE — PAGE"
      assert_includes contents, "display_meta_tags", "#{path} must render its title through meta-tags"
    end
  end

  test "canonical layouts keep surface and runtime names out of the site title" do
    CANONICAL_LAYOUTS.each_key do |path|
      site_title = Rails.root.join(path).read[/site: "([^"]*)"/, 1]

      assert_predicate site_title, :present?, "no site title found in #{path}"

      FORBIDDEN_SITE_WORDS.each do |word|
        assert_no_match(/\b#{word}\b/, site_title, "#{path} leaks #{word} into the site title")
      end
    end
  end

  test "canonical layouts do not reintroduce a local title variable" do
    CANONICAL_LAYOUTS.each_key do |path|
      contents = Rails.root.join(path).read

      assert_not_includes contents, "title_site", "layout #{path} must not precompute a title_site local"
      assert_not_includes contents, "surface =", "layout #{path} must not define a surface variable"
      assert_not_includes contents, "tld =", "layout #{path} must not define a tld variable"
    end
  end

  test "no layout or view builds a title outside meta-tags except the standalone documents" do
    allowed =
      %w(
        app/views/auth/shared/verified_subject_guidance.html.erb
        app/views/visa/shared/authorization_continuation.html.erb
      ).map { |path| Rails.root.join(path).to_s }

    offenders =
      Rails.root.glob("app/views/**/*.html.erb").select do |path|
        path.read.include?("<title>") && allowed.exclude?(path.to_s)
      end

    assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s },
                 "these HTML views hand-roll a <title>; render it through meta-tags instead"
  end

  test "layout roots remain constrained to Auth and Visa" do
    %w(auth visa).each do |surface|
      assert_predicate Rails.root.join("app/views/layouts/#{surface}"), :directory?
    end

    %w(base core docs edit guid help info news palm tech warp jump).each do |retired_root|
      assert_empty Rails.root.glob("app/views/layouts/#{retired_root}/**/*.erb")
    end
  end
end
