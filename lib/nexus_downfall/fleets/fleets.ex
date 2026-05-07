defmodule NexusDownfall.Fleets do
  @moduledoc """
  Fleets context.

  Manages fleet creation, composition, missions (transport, attack),
  fuel consumption (hydrogen), and mission scheduling via Oban.

  ## Phase roadmap
  - Phase 0: Module stub (structure only).
  - Phase 3: Fleet model, A* route resolution, mission lifecycle, Oban scheduling.
  """

  import Ecto.Query

  alias NexusDownfall.Fleets.{Fleet, FleetShip, ShipyardQueueItem}
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Planet, ProductionEngine}
  alias NexusDownfall.Repo
  alias NexusDownfall.Workers.ShipConstructionCompleteWorker

  @ship_catalog %{
    "light_freighter" => %{
      type: "light_freighter", tier: 1,
      name: "Carguero Ligero",
      description: "Transporte barato y rápido. Ideal para primeros saqueos y logística temprana.",
      hull: 120, shield: 15, attack: 5, accuracy: 35, agility: 55, speed: 110,
      fuel_per_s: 0.8, cargo: 5000,
      cost: %{raw_materials: 1500, microchips: 800, hydrogen: 300},
      build_time_seconds: 120
    },
    "heavy_freighter" => %{
      type: "heavy_freighter", tier: 1,
      name: "Carguero Pesado",
      description: "Mueve grandes cantidades de recursos, pero ralentiza la flota y necesita escolta.",
      hull: 420, shield: 60, attack: 20, accuracy: 30, agility: 25, speed: 70,
      fuel_per_s: 2.4, cargo: 25000,
      cost: %{raw_materials: 6000, microchips: 3500, hydrogen: 1600},
      build_time_seconds: 300
    },
    "light_fighter" => %{
      type: "light_fighter", tier: 1,
      name: "Caza Ligero",
      description: "Nave rápida y barata. Excelente para cazar cargueros y bombarderos mal protegidos.",
      hull: 90, shield: 20, attack: 35, accuracy: 68, agility: 85, speed: 150,
      fuel_per_s: 1.2, cargo: 60,
      cost: %{raw_materials: 1200, microchips: 600, hydrogen: 450},
      build_time_seconds: 90
    },
    "corvette" => %{
      type: "corvette", tier: 1,
      name: "Corbeta",
      description: "Primera nave militar estable. Protege cargueros y da consistencia a flotas tempranas.",
      hull: 220, shield: 45, attack: 80, accuracy: 60, agility: 62, speed: 115,
      fuel_per_s: 2.0, cargo: 120,
      cost: %{raw_materials: 3500, microchips: 1800, hydrogen: 900},
      build_time_seconds: 180
    },
    "missile_corvette" => %{
      type: "missile_corvette", tier: 1,
      name: "Corbeta Misilera",
      description: "Nave de daño inicial. Muy buena para romper escudos y defensas ligeras, mala en combates largos.",
      hull: 180, shield: 25, attack: 145, accuracy: 52, agility: 50, speed: 95,
      fuel_per_s: 2.8, cargo: 80,
      cost: %{raw_materials: 4200, microchips: 2500, hydrogen: 1800},
      build_time_seconds: 200
    },
    "heavy_fighter" => %{
      type: "heavy_fighter", tier: 2,
      name: "Caza Pesado",
      description: "Nave rápida para saqueos serios. Tiene carga propia y buena pegada contra objetivos vulnerables.",
      hull: 320, shield: 70, attack: 130, accuracy: 72, agility: 78, speed: 135,
      fuel_per_s: 5.2, cargo: 900,
      cost: %{raw_materials: 13000, microchips: 6500, hydrogen: 5500},
      build_time_seconds: 400
    },
    "frigate" => %{
      type: "frigate", tier: 2,
      name: "Fragata",
      description: "Núcleo militar del mid-game. Sirve para ataque, defensa y escolta.",
      hull: 550, shield: 120, attack: 190, accuracy: 64, agility: 45, speed: 85,
      fuel_per_s: 4.5, cargo: 300,
      cost: %{raw_materials: 15000, microchips: 9000, hydrogen: 4000},
      build_time_seconds: 500
    },
    "light_destroyer" => %{
      type: "light_destroyer", tier: 2,
      name: "Destructor Ligero",
      description: "Counter directo contra enjambres de cazas, corbetas y raiders.",
      hull: 680, shield: 160, attack: 150, accuracy: 78, agility: 42, speed: 75,
      fuel_per_s: 5.0, cargo: 200,
      cost: %{raw_materials: 18000, microchips: 12000, hydrogen: 4500},
      build_time_seconds: 550
    },
    "bomber" => %{
      type: "bomber", tier: 2,
      name: "Bombardero",
      description: "Nave especializada en destruir defensas. Necesita escolta.",
      hull: 900, shield: 160, attack: 520, accuracy: 45, agility: 20, speed: 50,
      fuel_per_s: 10.0, cargo: 500,
      cost: %{raw_materials: 52000, microchips: 38000, hydrogen: 24000},
      build_time_seconds: 1200
    },
    "blocker" => %{
      type: "blocker", tier: 2,
      name: "Bloqueador",
      description: "Nave diseñada para misiones de bloqueo planetario. No gana por daño, gana por control estratégico.",
      hull: 1500, shield: 450, attack: 120, accuracy: 55, agility: 18, speed: 42,
      fuel_per_s: 12.0, cargo: 3000,
      cost: %{raw_materials: 60000, microchips: 50000, hydrogen: 30000},
      build_time_seconds: 1500
    },
    "colonizer" => %{
      type: "colonizer", tier: 2,
      name: "Colonizadora",
      description: "Permite fundar nuevas colonias. Es estratégica, cara y debe protegerse.",
      hull: 1800, shield: 500, attack: 20, accuracy: 25, agility: 8, speed: 35,
      fuel_per_s: 18.0, cargo: 100_000,
      cost: %{raw_materials: 120_000, microchips: 85_000, hydrogen: 70_000},
      build_time_seconds: 3000
    },
    "cruiser" => %{
      type: "cruiser", tier: 3,
      name: "Crucero",
      description: "Nave pesada estable. Protege bombarderos, bloqueadores y naves estratégicas.",
      hull: 1200, shield: 300, attack: 380, accuracy: 62, agility: 32, speed: 65,
      fuel_per_s: 8.5, cargo: 1000,
      cost: %{raw_materials: 42000, microchips: 26000, hydrogen: 12000},
      build_time_seconds: 1000
    },
    "carrier" => %{
      type: "carrier", tier: 3,
      name: "Portadrones",
      description: "Mejora cazas y naves ligeras aliadas. No debe usarse sin escolta.",
      hull: 2500, shield: 700, attack: 220, accuracy: 58, agility: 15, speed: 45,
      fuel_per_s: 16.0, cargo: 2500,
      cost: %{raw_materials: 125_000, microchips: 95_000, hydrogen: 55_000},
      build_time_seconds: 2500
    },
    "ew_cruiser" => %{
      type: "ew_cruiser", tier: 3,
      name: "Crucero de Guerra Electrónica",
      description: "Nave técnica. Reduce escudos enemigos y mejora ataques contra objetivos resistentes.",
      hull: 800, shield: 1000, attack: 60, accuracy: 80, agility: 28, speed: 60,
      fuel_per_s: 13.0, cargo: 300,
      cost: %{raw_materials: 90_000, microchips: 125_000, hydrogen: 60_000},
      build_time_seconds: 2200
    },
    "battleship" => %{
      type: "battleship", tier: 3,
      name: "Acorazado",
      description: "Cazador de naves grandes. Excelente contra bloqueadores, cruceros, portadrones y top tier.",
      hull: 4200, shield: 1100, attack: 1250, accuracy: 58, agility: 10, speed: 35,
      fuel_per_s: 22.0, cargo: 3000,
      cost: %{raw_materials: 220_000, microchips: 150_000, hydrogen: 90_000},
      build_time_seconds: 4000
    },
    "leviathan" => %{
      type: "leviathan", tier: 4,
      name: "Leviathan",
      description: "Nave top tier de combate directo. Diseñada para decidir guerras de flota.",
      hull: 22000, shield: 6500, attack: 5500, accuracy: 62, agility: 4, speed: 18,
      fuel_per_s: 90.0, cargo: 10_000,
      cost: %{raw_materials: 1_500_000, microchips: 1_200_000, hydrogen: 750_000},
      build_time_seconds: 20000
    },
    "aphelion" => %{
      type: "aphelion", tier: 4,
      name: "Aphelion",
      description: "Plataforma de bombardeo estratégico. Destruye defensas e infraestructura planetaria.",
      hull: 16000, shield: 4500, attack: 2200, accuracy: 45, agility: 3, speed: 16,
      fuel_per_s: 120.0, cargo: 5000,
      cost: %{raw_materials: 1_300_000, microchips: 1_700_000, hydrogen: 1_000_000},
      build_time_seconds: 20000
    },
    "exodus" => %{
      type: "exodus", tier: 4,
      name: "Exodus",
      description: "Arca de conquista. Sirve para tomar planetas y sostener ocupaciones. No es una nave de combate principal.",
      hull: 28000, shield: 8000, attack: 900, accuracy: 35, agility: 2, speed: 12,
      fuel_per_s: 150.0, cargo: 250_000,
      cost: %{raw_materials: 2_000_000, microchips: 1_500_000, hydrogen: 1_300_000},
      build_time_seconds: 25000
    }
  }

  @admiral_options ["", "Admiral Alpha Card", "Admiral Beta Card"]

  def admiral_options, do: @admiral_options

  def ship_catalog do
    @ship_catalog
    |> Map.values()
    |> Enum.sort_by(&{&1.tier, &1.name})
  end

  def ship_definition(type), do: Map.get(@ship_catalog, type)

  def ship_build_time_seconds(type, quantity \\ 1) do
    case ship_definition(type) do
      %{build_time_seconds: base} -> base * quantity
      _ -> 0
    end
  end

  def ship_total_cost(type, quantity \\ 1) do
    case ship_definition(type) do
      %{cost: cost} ->
        Map.new(cost, fn {resource, amount} -> {resource, amount * quantity} end)

      _ ->
        %{}
    end
  end

  def list_planets_for_user(user_id) do
    Repo.all(
      from p in Planet,
        join: uu in assoc(p, :universe_user),
        join: s in assoc(p, :solar_system),
        where: uu.user_id == ^user_id,
        preload: [solar_system: s, universe_user: uu],
        order_by: [asc: uu.universe_id, asc: p.name]
    )
  end

  def list_fleets_for_user(user_id) do
    Repo.all(
      from f in Fleet,
        join: uu in assoc(f, :universe_user),
        where: uu.user_id == ^user_id,
        preload: [:ships, home_planet: [:solar_system]],
        order_by: [asc: f.name]
    )
  end

  def list_fleets_for_universe_user(universe_user_id) do
    Repo.all(
      from f in Fleet,
        where: f.universe_user_id == ^universe_user_id,
        preload: [:ships, home_planet: [:solar_system]],
        order_by: [asc: f.name]
    )
  end

  def list_fleets_for_planet(planet_id) do
    Repo.all(
      from f in Fleet,
        where: f.home_planet_id == ^planet_id,
        preload: [:ships],
        order_by: [asc: f.name]
    )
  end

  def list_shipyard_queue(planet_id) do
    Repo.all(
      from q in ShipyardQueueItem,
        where: q.planet_id == ^planet_id and q.status in ["queued", "building"],
        preload: [fleet: [:ships]],
        order_by: [asc: q.queue_position]
    )
  end

  def shipyard_panel_for_user_planet(planet_id, user_id) do
    planet = owned_planet!(planet_id, user_id)

    %{
      fleets: list_fleets_for_planet(planet.id),
      queue_items: list_shipyard_queue(planet.id),
      ship_catalog: ship_catalog()
    }
  end

  def create_fleet_for_user(user_id, attrs) do
    Repo.transaction(fn ->
      planet_id = parse_int!(Map.get(attrs, "planet_id") || Map.get(attrs, :planet_id))
      name = normalize_name(Map.get(attrs, "name") || Map.get(attrs, :name))
      admiral_name = normalize_optional(Map.get(attrs, "admiral_name") || Map.get(attrs, :admiral_name))

      planet = owned_planet_for_update(planet_id, user_id)

      if is_nil(planet), do: Repo.rollback(:not_found)

      fleet =
        %Fleet{}
        |> Fleet.changeset(%{
          name: name,
          admiral_name: admiral_name,
          universe_id: planet.universe_id,
          universe_user_id: planet.universe_user_id,
          home_planet_id: planet.id,
          status: "idle"
        })
        |> Repo.insert!()

      :ok = ensure_ship_slots(fleet.id)
      Repo.preload(fleet, [:ships, home_planet: [:solar_system]])
    end)
    |> normalize_transaction_result()
  rescue
    ArgumentError -> {:error, :invalid_fleet}
    Ecto.InvalidChangesetError -> {:error, :invalid_fleet}
  end

  def enqueue_ship_construction_for_user(planet_id, user_id, attrs) do
    Repo.transaction(fn ->
      fleet_id = parse_int!(Map.get(attrs, "fleet_id") || Map.get(attrs, :fleet_id))
      ship_type = Map.get(attrs, "ship_type") || Map.get(attrs, :ship_type)
      quantity = parse_int!(Map.get(attrs, "quantity") || Map.get(attrs, :quantity) || 1)

      if quantity <= 0, do: Repo.rollback(:invalid_quantity)

      ship = ship_definition(ship_type)
      if is_nil(ship), do: Repo.rollback(:unknown_ship)

      planet =
        owned_planet_for_update!(planet_id, user_id)
        |> refresh_planet_resources!()

      buildings = Planets.list_buildings(planet.id)
      spaceport = Enum.find(buildings, &(&1.type == "spaceport")) || %Building{level: 0}

      if spaceport.level < 1, do: Repo.rollback(:spaceport_required)

      fleet =
        Repo.one(
          from f in Fleet,
            join: uu in assoc(f, :universe_user),
            where: f.id == ^fleet_id and uu.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(fleet) ->
          Repo.rollback(:fleet_not_found)

        fleet.universe_user_id != planet.universe_user_id ->
          Repo.rollback(:fleet_unavailable)

        fleet.home_planet_id != planet.id ->
          Repo.rollback(:fleet_unavailable)

        true ->
          total_cost = ship_total_cost(ship_type, quantity)

          unless ProductionEngine.can_afford?(planet, total_cost) do
            Repo.rollback(:insufficient_resources)
          end

          planet
          |> Ecto.Changeset.cast(ProductionEngine.deduct_cost(planet, total_cost), Map.keys(total_cost))
          |> Repo.update!()

          next_position =
            (Repo.one(
               from q in ShipyardQueueItem,
                 where: q.planet_id == ^planet.id,
                 order_by: [desc: q.queue_position],
                 select: q.queue_position,
                 limit: 1,
                 lock: "FOR UPDATE"
             ) || 0) + 1

          now = DateTime.utc_now() |> DateTime.truncate(:second)
          build_seconds = ship_build_time_seconds(ship_type)
          has_active =
            Repo.exists?(
              from q in ShipyardQueueItem,
                where: q.planet_id == ^planet.id and q.status == "building"
            )

          item =
            %ShipyardQueueItem{}
            |> ShipyardQueueItem.changeset(%{
              planet_id: planet.id,
              fleet_id: fleet.id,
              ship_type: ship_type,
              quantity: quantity,
              queue_position: next_position,
              status: if(has_active, do: "queued", else: "building"),
              build_seconds: build_seconds,
              started_at: if(has_active, do: nil, else: now),
              finish_at: if(has_active, do: nil, else: DateTime.add(now, build_seconds, :second))
            })
            |> Repo.insert!()

          item =
            if item.status == "building" do
              case schedule_queue_item(item) do
                {:ok, scheduled_item} -> scheduled_item
                {:error, reason} -> Repo.rollback(reason)
              end
            else
              item
            end

          :telemetry.execute(
            [:nexus_downfall, :fleets, :ship_queued],
            %{count: quantity},
            %{planet_id: planet.id, fleet_id: fleet.id, ship_type: ship_type}
          )

          Repo.preload(item, [fleet: [:ships]])
      end
    end)
    |> normalize_transaction_result()
  rescue
    ArgumentError -> {:error, :invalid_queue_request}
    Ecto.InvalidChangesetError -> {:error, :invalid_queue_request}
  end

  def complete_queue_item(queue_item_id) do
    Repo.transaction(fn ->
      item =
        Repo.one(
          from q in ShipyardQueueItem,
            where: q.id == ^queue_item_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(item) ->
          :ok

        item.status != "building" or is_nil(item.finish_at) ->
          :ok

        true ->
          :ok = ensure_ship_slots(item.fleet_id)

          ship_row =
            Repo.one!(
              from fs in FleetShip,
                where: fs.fleet_id == ^item.fleet_id and fs.ship_type == ^item.ship_type,
                lock: "FOR UPDATE"
            )

          ship_row
          |> FleetShip.changeset(%{quantity: ship_row.quantity + 1})
          |> Repo.update!()

          :telemetry.execute(
            [:nexus_downfall, :fleets, :ship_construction_completed],
            %{count: 1},
            %{planet_id: item.planet_id, fleet_id: item.fleet_id, ship_type: item.ship_type}
          )

          if item.quantity > 1 do
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            next_cycle_item =
              item
              |> ShipyardQueueItem.changeset(%{
                quantity: item.quantity - 1,
                started_at: now,
                finish_at: DateTime.add(now, item.build_seconds, :second),
                oban_job_id: nil
              })
              |> Repo.update!()

            case schedule_queue_item(next_cycle_item) do
              {:ok, _scheduled_item} -> :ok
              {:error, reason} -> Repo.rollback(reason)
            end
          else
            item
            |> ShipyardQueueItem.changeset(%{status: "completed", oban_job_id: nil})
            |> Repo.update!()

            start_next_queue_item!(item.planet_id)
            :ok
          end
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> reason
    end
  end

  def total_ships(fleet) do
    Enum.reduce(fleet.ships || [], 0, fn ship, acc -> acc + ship.quantity end)
  end

  def ship_quantity(fleet, ship_type) do
    fleet.ships
    |> List.wrap()
    |> Enum.find_value(0, fn ship -> if ship.ship_type == ship_type, do: ship.quantity end)
  end

  defp ensure_ship_slots(fleet_id) do
    FleetShip.ship_types()
    |> Enum.each(fn ship_type ->
      %FleetShip{}
      |> FleetShip.changeset(%{fleet_id: fleet_id, ship_type: ship_type, quantity: 0})
      |> Repo.insert(on_conflict: :nothing)
    end)

    :ok
  end

  defp start_next_queue_item!(planet_id) do
    next_item =
      Repo.one(
        from q in ShipyardQueueItem,
          where: q.planet_id == ^planet_id and q.status == "queued",
          order_by: [asc: q.queue_position],
          limit: 1,
          lock: "FOR UPDATE"
      )

    if next_item do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      started_item =
        next_item
        |> ShipyardQueueItem.changeset(%{
          status: "building",
          started_at: now,
          finish_at: DateTime.add(now, next_item.build_seconds, :second)
        })
        |> Repo.update!()

      case schedule_queue_item(started_item) do
        {:ok, _} -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end

    :ok
  end

  defp schedule_queue_item(item) do
    case ShipConstructionCompleteWorker.new(
           %{"queue_item_id" => item.id},
           scheduled_at: item.finish_at
         )
         |> Oban.insert() do
      {:ok, job} ->
        updated_item =
          item
          |> ShipyardQueueItem.changeset(%{oban_job_id: job.id})
          |> Repo.update!()

        {:ok, updated_item}

      {:error, _changeset} ->
        {:error, :queue_scheduling_failed}
    end
  end

  defp refresh_planet_resources!(planet) do
    {:ok, updated} = Planets.apply_production_tick(planet)
    updated
  end

  defp owned_planet!(planet_id, user_id) do
    Repo.one!(
      from p in Planet,
        join: uu in assoc(p, :universe_user),
        where: p.id == ^planet_id and uu.user_id == ^user_id,
        preload: [universe_user: uu]
    )
  end

  defp owned_planet_for_update!(planet_id, user_id) do
    Repo.one!(
      from p in Planet,
        join: uu in assoc(p, :universe_user),
        where: p.id == ^planet_id and uu.user_id == ^user_id,
        preload: [universe_user: uu],
        lock: "FOR UPDATE"
    )
  end

  defp owned_planet_for_update(planet_id, user_id) do
    Repo.one(
      from p in Planet,
        join: uu in assoc(p, :universe_user),
        where: p.id == ^planet_id and uu.user_id == ^user_id,
        preload: [universe_user: uu],
        lock: "FOR UPDATE"
    )
  end

  defp normalize_name(name) when is_binary(name), do: String.trim(name)
  defp normalize_name(_), do: ""

  defp normalize_optional(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp normalize_optional(_), do: nil

  defp parse_int!(value) when is_integer(value), do: value
  defp parse_int!(value) when is_binary(value), do: String.to_integer(value)

  defp normalize_transaction_result({:ok, value}), do: {:ok, value}
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}
end
