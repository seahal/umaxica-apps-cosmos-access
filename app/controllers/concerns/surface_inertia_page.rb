# typed: false
# frozen_string_literal: true

# Supplies shared methods for controllers that render Inertia pages. Each concrete controller
# declares its own literal surface layout and shared chrome props next to the concern inclusion.
# `render inertia: true` derives the component name from the same controller_path.
#
# It also brings in the surface chrome, because a page rendered into the slim Inertia shell has no
# header or footer of its own: those are React components fed by the shared `chrome` prop.
module SurfaceInertiaPage
  extend ActiveSupport::Concern

  include SurfaceChrome

  private

  # Page prop keys are composed from the screen scope, so they cannot be literals at the call site;
  # passing the composed key through here keeps every page translation lookup in one place, the same
  # way `SurfaceChrome#chrome_t` does for the chrome props.
  def page_t(key, **)
    t(key, **)
  end

  # Parent of signed-in self-service screens is Dashboard on Base and Warp. Auth uses Root.
  # The href is a route helper so
  # PreferenceGlobal can attach the request region (`ri`) and any other context params.
  def dashboard_up_link(label: t("actions.up"))
    family, surface = controller_path.to_s.split("/").first(2)
    helper =
      if family == "auth"
        "#{family}_#{surface}_root_path"
      else
        "#{family}_#{surface}_dashboard_path"
      end

    {
      label: label,
      href: public_send(helper, ri: params[:ri]),
    }
  end
end
