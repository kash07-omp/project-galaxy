defmodule NexusDownfallWeb.Gettext do
  @moduledoc """
  Gettext backend for NexusDownfallWeb.

  Usage in templates / LiveViews (via html_helpers):
      use Gettext, backend: NexusDownfallWeb.Gettext
      gettext("Hello world")
  """

  use Gettext.Backend, otp_app: :nexus_downfall
end
