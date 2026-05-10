defmodule NexusDownfallWeb.UnitDetailModal do
  @moduledoc """
  Shared modal used to display ship and defense details.
  """

  use Phoenix.Component
  use Gettext, backend: NexusDownfallWeb.Gettext

  attr :id, :string, default: "unit-detail-modal"
  attr :unit_detail, :map, required: true
  attr :close_event, :string, required: true

  def unit_detail_modal(assigns) do
    ~H"""
    <div id={@id} class="absolute inset-0 z-30 flex items-center justify-center bg-black/80 p-5 backdrop-blur-sm">
      <div class="absolute inset-0" phx-click={@close_event} />
      <div class="relative z-10 w-full max-w-2xl overflow-hidden rounded-2xl border border-cyan-900/70 bg-gray-950 shadow-2xl">
        <div class="grid gap-0 md:grid-cols-[220px_minmax(0,1fr)]">
          <div class="relative min-h-[220px] bg-gray-900">
            <img
              src={@unit_detail.image_path}
              class="absolute inset-0 h-full w-full object-contain p-6"
              draggable="false"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-gray-950 via-transparent to-cyan-950/20" />
          </div>

          <div class="flex max-h-[72vh] flex-col overflow-y-auto p-5">
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-xs font-bold uppercase tracking-widest text-cyan-400">
                  {gettext("Details")}
                </p>
                <h3 class="mt-1 text-2xl font-bold leading-tight text-white">
                  {@unit_detail.name}
                </h3>
              </div>

              <button
                phx-click={@close_event}
                class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-900 text-gray-400 transition hover:bg-gray-800 hover:text-white"
              >
                x
              </button>
            </div>

            <p class="mt-4 text-sm leading-relaxed text-gray-300">
              {@unit_detail.description}
            </p>

            <div class="mt-5 grid grid-cols-2 gap-2 sm:grid-cols-3">
              <%= for {label, value} <- @unit_detail.stats do %>
                <div class="rounded-lg border border-gray-800 bg-gray-900/70 px-3 py-2">
                  <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">
                    {label}
                  </div>
                  <div class="mt-1 break-words text-sm font-semibold text-gray-100">
                    {value}
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end