defmodule NexusDownfallWeb.CoreComponents do
  @moduledoc """
  Core reusable UI components for Nexus: Downfall.

  Components here are the building blocks of the sci-fi UI. More complex
  game-specific components (resource bars, fleet panels, etc.) live in
  dedicated component modules under `NexusDownfallWeb.Components.*`.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # ---------------------------------------------------------------------------
  # Flash messages
  # ---------------------------------------------------------------------------

  attr :id, :string, default: nil
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash key lookup"
  attr :rest, :global

  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 shadow-md",
        @kind == :info && "bg-emerald-950 text-emerald-300 ring-emerald-500",
        @kind == :error && "bg-rose-950 text-rose-300 ring-rose-500"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button
        type="button"
        class="absolute top-1 right-1 p-2 opacity-40 hover:opacity-70"
        aria-label="close"
      >
        <span aria-hidden="true">✕</span>
      </button>
    </div>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages from the socket"

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="assertive">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title="Connection lost"
        phx-disconnected={JS.show(to: "#client-error")}
        phx-connected={JS.hide(to: "#client-error")}
        hidden
      >
        Attempting to reconnect…
      </.flash>
      <.flash
        id="server-error"
        kind={:error}
        title="Server error"
        phx-disconnected={JS.show(to: "#server-error")}
        phx-connected={JS.hide(to: "#server-error")}
        hidden
      >
        Hang on while we get back online.
      </.flash>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Button
  # ---------------------------------------------------------------------------

  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-cyan-600 hover:bg-cyan-500",
        "py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Modal
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && JS.show(to: "##{@id}")}
      phx-remove={hide_modal(@id)}
      class="hidden relative z-50"
    >
      <div id={"#{@id}-bg"} class="bg-black/70 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="bg-gray-900 shadow-lg rounded-xl border border-gray-700 p-6 sm:p-10"
              data-cancel={JS.exec(@on_cancel, "phx-remove")}
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="text-gray-400 hover:text-gray-200"
                  aria-label="close"
                >
                  <span aria-hidden="true">✕</span>
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(to: "##{id}-bg", transition: "fade-out")
    |> JS.hide(to: "##{id}-container", transition: "fade-out-scale")
    |> JS.hide(to: "##{id}")
  end

  # ---------------------------------------------------------------------------
  # Header
  # ---------------------------------------------------------------------------

  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-gray-100">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-gray-400">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none"><%= render_slot(@actions) %></div>
    </header>
    """
  end
end
