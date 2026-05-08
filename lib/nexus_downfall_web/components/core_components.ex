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
  attr :kind, :atom, values: [:info, :success, :warning, :error], doc: "used for styling and flash key lookup"
  attr :duration, :integer, default: 4500, doc: "auto-dismiss timeout in milliseconds"
  attr :rest, :global

  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
      phx-hook="AutoDismissFlash"
      data-flash-key={@kind}
      data-duration={@duration}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 shadow-md",
        @kind == :info && "bg-emerald-950 text-emerald-300 ring-emerald-500",
        @kind == :success && "bg-emerald-950 text-emerald-300 ring-emerald-500",
        @kind == :warning && "bg-amber-950 text-amber-200 ring-amber-500",
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
      <.flash kind={:success} flash={@flash} />
      <.flash kind={:warning} flash={@flash} />
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
      <div
        id={"#{@id}-bg"}
        class="bg-black/70 fixed inset-0 transition-opacity"
        aria-hidden="true"
        phx-click={JS.exec("data-cancel", to: "##{@id}")}
      />
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

  # ---------------------------------------------------------------------------
  # Form helpers — label, input, simple_form
  # ---------------------------------------------------------------------------

  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={["block text-sm font-medium text-gray-300 mb-1", @class]}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number
               password range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = Enum.map(field.errors, &translate_error(&1))

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, errors)
    |> assign_new(:name, fn -> if assigns[:multiple], do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns = assign_new(assigns, :checked, fn ->
      Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
    end)

    ~H"""
    <div>
      <label class="flex items-center gap-4 text-sm leading-6 text-gray-300">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-gray-600 bg-gray-800 text-cyan-500 focus:ring-cyan-500"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-md border border-gray-600 bg-gray-800 text-gray-100
               shadow-sm focus:border-cyan-500 focus:ring-cyan-500 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-1 block w-full rounded-md border bg-gray-800 text-gray-100 shadow-sm sm:text-sm",
          "min-h-[6rem] focus:ring-cyan-500",
          @errors == [] && "border-gray-600 focus:border-cyan-500",
          @errors != [] && "border-rose-500 focus:border-rose-500"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-1 block w-full rounded-md border bg-gray-800 text-gray-100 shadow-sm sm:text-sm",
          "focus:ring-cyan-500",
          @errors == [] && "border-gray-600 focus:border-cyan-500",
          @errors != [] && "border-rose-500 focus:border-rose-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc "Renders a validation error message."
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-1 flex gap-1 text-sm leading-6 text-rose-400">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # ---------------------------------------------------------------------------
  # Translation helper (required by input/1)
  # ---------------------------------------------------------------------------

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(NexusDownfallWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(NexusDownfallWeb.Gettext, "errors", msg, opts)
    end
  end
end
