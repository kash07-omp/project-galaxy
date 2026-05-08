defmodule NexusDownfallWeb.GalaxyLive do
  @moduledoc "Galaxy map view — SVG with systems and hyperlanes."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Universe

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  # Canvas dimensions for the SVG viewport
  @vw 800
  @vh 600

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  def mount(%{"galaxy_id" => galaxy_id}, _session, socket) do
    galaxy = Universe.get_galaxy_with_systems!(galaxy_id)
    hyperlinks = Universe.list_hyperlinks_for_galaxy(galaxy.id)

    {:ok,
     socket
     |> assign(:galaxy, galaxy)
     |> assign(:systems, galaxy.solar_systems)
     |> assign(:hyperlinks, hyperlinks)
     |> assign(:vw, @vw)
     |> assign(:vh, @vh)
     |> assign(:show_user_menu, false)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}

  def handle_event("close_menu", _, socket),
    do: {:noreply, assign(socket, :show_user_menu, false)}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Normalise system coordinates into SVG canvas space with padding
  defp to_svg_coords(systems, vw, vh) do
    xs = Enum.map(systems, & &1.x)
    ys = Enum.map(systems, & &1.y)

    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)

    pad = 80
    range_x = max(max_x - min_x, 1)
    range_y = max(max_y - min_y, 1)

    Enum.map(systems, fn s ->
      sx = pad + (s.x - min_x) / range_x * (vw - pad * 2)
      sy = pad + (s.y - min_y) / range_y * (vh - pad * 2)
      Map.put(s, :sx, Float.round(sx, 1)) |> Map.put(:sy, Float.round(sy, 1))
    end)
  end

  defp system_color(system, current_user_id) do
    planets = system.planets

    cond do
      Enum.any?(planets, fn p ->
        p.universe_user_id != nil and
          match?(%{universe_user: %{user_id: ^current_user_id}}, p.universe_user)
      end) ->
        "cyan"

      Enum.any?(planets, & &1.universe_user_id != nil) ->
        "orange"

      true ->
        "gray"
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    positioned = to_svg_coords(assigns.systems, assigns.vw, assigns.vh)
    pos_by_id = Map.new(positioned, &{&1.id, &1})
    current_uid = assigns.current_user.id

    assigns =
      assigns
      |> assign(:positioned, positioned)
      |> assign(:pos_by_id, pos_by_id)
      |> assign(:current_uid, current_uid)

    ~H"""
    <div class="flex flex-col h-screen bg-gray-950 font-sans overflow-hidden select-none">

      <!-- ══════ TOPBAR ══════ -->
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab="galaxy"
        galaxy_id={@galaxy.id}
        context_label={gettext("Galaxy %{number}", number: @galaxy.number)}
        notifications={@topbar_notifications}
        notifications_unread_count={@topbar_notifications_unread_count}
        show_notifications_menu={@show_notifications_menu}
      />

      <!-- ══════ GALAXY MAP ══════ -->
      <main class="flex-1 overflow-hidden flex items-center justify-center p-4">
        <div class="relative bg-gray-900 border border-gray-700 rounded-lg overflow-hidden shadow-2xl"
             style={"width:#{@vw}px;max-width:100%;aspect-ratio:#{@vw}/#{@vh}"}>

          <svg
            viewBox={"0 0 #{@vw} #{@vh}"}
            class="w-full h-full"
            xmlns="http://www.w3.org/2000/svg"
          >
            <!-- Deep space background stars (static decoration) -->
            <rect width={@vw} height={@vh} fill="#060d1a"/>
            <%= for {sx, sy} <- Enum.map(1..60, fn i -> {rem(i * 137 + 50, @vw - 20) + 10, rem(i * 79 + 30, @vh - 20) + 10} end) do %>
              <circle cx={sx} cy={sy} r="0.8" fill="rgba(200,220,255,0.4)" />
            <% end %>

            <!-- Hyperlanes -->
            <%= for hl <- @hyperlinks do %>
              <% pa = Map.get(@pos_by_id, hl.system_a_id) %>
              <% pb = Map.get(@pos_by_id, hl.system_b_id) %>
              <%= if pa && pb do %>
                <line
                  x1={pa.sx} y1={pa.sy}
                  x2={pb.sx} y2={pb.sy}
                  stroke="rgba(99,179,237,0.25)"
                  stroke-width="1.5"
                  stroke-dasharray="5,4"
                />
              <% end %>
            <% end %>

            <!-- Solar systems -->
            <%= for sys <- @positioned do %>
              <% color = system_color(sys, @current_uid) %>
              <% {fill, stroke, label_color} = case color do
                "cyan"   -> {"rgba(6,182,212,0.2)", "#22d3ee", "#67e8f9"}
                "orange" -> {"rgba(234,88,12,0.2)",  "#f97316", "#fdba74"}
                _        -> {"rgba(55,65,81,0.3)",   "#4b5563", "#9ca3af"}
              end %>
              <.link navigate={~p"/systems/#{sys.id}"}>
                <g class="cursor-pointer" phx-click={JS.navigate(~p"/systems/#{sys.id}")}>
                  <!-- Glow ring -->
                  <circle cx={sys.sx} cy={sys.sy} r="18" fill={fill} />
                  <!-- System circle -->
                  <circle cx={sys.sx} cy={sys.sy} r="9" fill={fill} stroke={stroke} stroke-width="1.5"/>
                  <!-- System star dot -->
                  <circle cx={sys.sx} cy={sys.sy} r="4" fill={stroke} />
                  <!-- System number label -->
                  <text
                    x={sys.sx}
                    y={sys.sy + 26}
                    text-anchor="middle"
                    font-size="10"
                    font-family="'Share Tech Mono', monospace"
                    fill={label_color}
                  >
                    <%= gettext("System") %> <%= sys.number %>
                  </text>
                </g>
              </.link>
            <% end %>
          </svg>
        </div>
      </main>

      <!-- ══════ LEGEND ══════ -->
      <footer class="bg-gray-900/80 border-t border-gray-800 px-4 py-2 flex gap-6 text-xs text-gray-400 justify-center">
        <span class="flex items-center gap-1.5">
          <span class="inline-block w-3 h-3 rounded-full bg-cyan-400"></span>
          <%= gettext("Own planet") %>
        </span>
        <span class="flex items-center gap-1.5">
          <span class="inline-block w-3 h-3 rounded-full bg-orange-400"></span>
          <%= gettext("Colonised") %>
        </span>
        <span class="flex items-center gap-1.5">
          <span class="inline-block w-3 h-3 rounded-full bg-gray-600"></span>
          <%= gettext("Uninhabited") %>
        </span>
      </footer>

    </div>
    """
  end
end
