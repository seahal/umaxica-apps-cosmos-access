# frozen_string_literal: true

# Pure request presentation context. The includer explicitly registers its callbacks and
# supplies request, params and redirect_to. No persisted Preference or actor is loaded.
module VisaBrowserRequestContext
  private

  def with_visa_request_locale
    requested = params[:lx]
    locale =
      case requested
      when String
        case requested.downcase
        when "en" then :en
        when "ja" then :ja
        else I18n.default_locale
        end
      else I18n.default_locale
      end
    I18n.with_locale(locale) { yield }
  end

  def normalize_visa_browser_region!
    return if request.format.json?

    query = request.query_parameters.dup
    if query.key?("lx") && (!query["lx"].is_a?(String) || %w(en ja).exclude?(query["lx"].downcase))
      query.delete("lx")
    end
    normalized = RequestContextContract.normalize(:ri, params[:ri])
    if RequestContextContract.allowed_regions.include?(normalized)
      return unless (request.get? || request.head?) && query != request.query_parameters
    else
      return unless request.get? || request.head? || params[:ri].present?

      query["ri"] = RequestContextContract.default_region
    end
    target = "#{request.path}?#{query.to_query}"
    redirect_to(target, allow_other_host: false, status: (request.get? || request.head?) ? :found : :see_other)
  end
end
