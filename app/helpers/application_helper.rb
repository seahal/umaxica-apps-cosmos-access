# typed: false
# frozen_string_literal: true

module ApplicationHelper
  public

  def page_title(title = nil)
    if title.present?
      content_for(:page_title, title)
      title
    else
      # Brand and TLD are a locale-independent contract owned by the layout's
      # meta-tags `site:` value, so there is no translated default here. A page
      # without a title renders the site title alone, which is the root contract.
      content_for(:page_title)
    end
  end

  def theme_cookie_value(value = nil)
    raw = (value || Actor.preferences.theme).to_s.downcase
    {
      "dr" => "dark",
      "dark" => "dark",
      "li" => "light",
      "light" => "light",
      "sy" => "system",
      "system" => "system",
    }[raw] || "system"
  end

  def theme_html_class(value = nil)
    theme = theme_cookie_value(value)
    classes = ["theme-#{theme}"]
    classes << "dark" if theme == "dark"
    classes.join(" ")
  end
end
