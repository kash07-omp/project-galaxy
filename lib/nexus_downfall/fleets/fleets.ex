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

  alias NexusDownfall.Fleets.{Fleet, FleetMission, FleetShip, Pathfinder, ShipyardQueueItem}
  alias NexusDownfall.GameplaySettings
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Planet, ProductionEngine}
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, Hyperlink, SolarSystem}
  alias NexusDownfall.Workers.{FleetMissionWorker, ShipConstructionCompleteWorker}
  alias NexusDownfall.Cards

  @active_mission_phases ["outbound", "colonizing", "returning"]

  @ship_catalog %{
    "light_freighter" => %{
      type: "light_freighter", tier: 1,
      name: "Light Freighter",
      description: "Transporte barato y rápido. Ideal para primeros saqueos y logística temprana.",
      hull: 120, shield: 15, attack: 5, accuracy: 35, agility: 55, speed: 110,
      fuel_per_s: 0.8, cargo: 5000,
      cost: %{raw_materials: 1500, microchips: 800, hydrogen: 300},
      build_time_seconds: 120
    },
    "heavy_freighter" => %{
      type: "heavy_freighter", tier: 1,
      name: "Heavy Freighter",
      description: "Mueve grandes cantidades de recursos, pero ralentiza la flota y necesita escolta.",
      hull: 420, shield: 60, attack: 20, accuracy: 30, agility: 25, speed: 70,
      fuel_per_s: 2.4, cargo: 25000,
      cost: %{raw_materials: 6000, microchips: 3500, hydrogen: 1600},
      build_time_seconds: 300
    },
    "light_fighter" => %{
      type: "light_fighter", tier: 1,
      name: "Light Fighter",
      description: "Nave rápida y barata. Excelente para cazar cargueros y bombarderos mal protegidos.",
      hull: 90, shield: 20, attack: 35, accuracy: 68, agility: 85, speed: 150,
      fuel_per_s: 1.2, cargo: 60,
      cost: %{raw_materials: 1200, microchips: 600, hydrogen: 450},
      build_time_seconds: 90
    },
    "corvette" => %{
      type: "corvette", tier: 1,
      name: "Corvette",
      description: "Primera nave militar estable. Protege cargueros y da consistencia a flotas tempranas.",
      hull: 220, shield: 45, attack: 80, accuracy: 60, agility: 62, speed: 115,
      fuel_per_s: 2.0, cargo: 120,
      cost: %{raw_materials: 3500, microchips: 1800, hydrogen: 900},
      build_time_seconds: 180
    },
    "missile_corvette" => %{
      type: "missile_corvette", tier: 1,
      name: "Missile Corvette",
      description: "Nave de daño inicial. Muy buena para romper escudos y defensas ligeras, mala en combates largos.",
      hull: 180, shield: 25, attack: 145, accuracy: 52, agility: 50, speed: 95,
      fuel_per_s: 2.8, cargo: 80,
      cost: %{raw_materials: 4200, microchips: 2500, hydrogen: 1800},
      build_time_seconds: 200
    },
    "heavy_fighter" => %{
      type: "heavy_fighter", tier: 2,
      name: "Heavy Fighter",
      description: "Nave rápida para saqueos serios. Tiene carga propia y buena pegada contra objetivos vulnerables.",
      hull: 320, shield: 70, attack: 130, accuracy: 72, agility: 78, speed: 135,
      fuel_per_s: 5.2, cargo: 900,
      cost: %{raw_materials: 13000, microchips: 6500, hydrogen: 5500},
      build_time_seconds: 400
    },
    "frigate" => %{
      type: "frigate", tier: 2,
      name: "Frigate",
      description: "Núcleo militar del mid-game. Sirve para ataque, defensa y escolta.",
      hull: 550, shield: 120, attack: 190, accuracy: 64, agility: 45, speed: 85,
      fuel_per_s: 4.5, cargo: 300,
      cost: %{raw_materials: 15000, microchips: 9000, hydrogen: 4000},
      build_time_seconds: 500
    },
    "light_destroyer" => %{
      type: "light_destroyer", tier: 2,
      name: "Light Destroyer",
      description: "Counter directo contra enjambres de cazas, corbetas y raiders.",
      hull: 680, shield: 160, attack: 150, accuracy: 78, agility: 42, speed: 75,
      fuel_per_s: 5.0, cargo: 200,
      cost: %{raw_materials: 18000, microchips: 12000, hydrogen: 4500},
      build_time_seconds: 550
    },
    "bomber" => %{
      type: "bomber", tier: 2,
      name: "Bomber",
      description: "Nave especializada en destruir defensas. Necesita escolta.",
      hull: 900, shield: 160, attack: 520, accuracy: 45, agility: 20, speed: 50,
      fuel_per_s: 10.0, cargo: 500,
      cost: %{raw_materials: 52000, microchips: 38000, hydrogen: 24000},
      build_time_seconds: 1200
    },
    "blocker" => %{
      type: "blocker", tier: 2,
      name: "Blocker",
      description: "Nave diseñada para misiones de bloqueo planetario. No gana por daño, gana por control estratégico.",
      hull: 1500, shield: 450, attack: 120, accuracy: 55, agility: 18, speed: 42,
      fuel_per_s: 12.0, cargo: 3000,
      cost: %{raw_materials: 60000, microchips: 50000, hydrogen: 30000},
      build_time_seconds: 1500
    },
    "colonizer" => %{
      type: "colonizer", tier: 2,
      name: "Colonizer",
      description: "Permite fundar nuevas colonias. Es estratégica, cara y debe protegerse.",
      hull: 1800, shield: 500, attack: 20, accuracy: 25, agility: 8, speed: 35,
      fuel_per_s: 18.0, cargo: 100_000,
      cost: %{raw_materials: 120_000, microchips: 85_000, hydrogen: 70_000},
      build_time_seconds: 3000
    },
    "cruiser" => %{
      type: "cruiser", tier: 3,
      name: "Cruiser",
      description: "Nave pesada estable. Protege bombarderos, bloqueadores y naves estratégicas.",
      hull: 1200, shield: 300, attack: 380, accuracy: 62, agility: 32, speed: 65,
      fuel_per_s: 8.5, cargo: 1000,
      cost: %{raw_materials: 42000, microchips: 26000, hydrogen: 12000},
      build_time_seconds: 1000
    },
    "carrier" => %{
      type: "carrier", tier: 3,
      name: "Drone Carrier",
      description: "Mejora cazas y naves ligeras aliadas. No debe usarse sin escolta.",
      hull: 2500, shield: 700, attack: 220, accuracy: 58, agility: 15, speed: 45,
      fuel_per_s: 16.0, cargo: 2500,
      cost: %{raw_materials: 125_000, microchips: 95_000, hydrogen: 55_000},
      build_time_seconds: 2500
    },
    "ew_cruiser" => %{
      type: "ew_cruiser", tier: 3,
      name: "Electronic Warfare Cruiser",
      description: "Nave técnica. Reduce escudos enemigos y mejora ataques contra objetivos resistentes.",
      hull: 800, shield: 1000, attack: 60, accuracy: 80, agility: 28, speed: 60,
      fuel_per_s: 13.0, cargo: 300,
      cost: %{raw_materials: 90_000, microchips: 125_000, hydrogen: 60_000},
      build_time_seconds: 2200
    },
    "battleship" => %{
      type: "battleship", tier: 3,
      name: "Battleship",
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
        preload: [:ships, :admiral_card, home_planet: [:solar_system]],
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
      admiral_card_id = parse_optional_int(Map.get(attrs, "admiral_card_id") || Map.get(attrs, :admiral_card_id))

      planet = owned_planet_for_update(planet_id, user_id)

      if is_nil(planet), do: Repo.rollback(:not_found)

      if admiral_card_id && !Cards.user_owns_card?(planet.universe_user_id, admiral_card_id) do
        Repo.rollback(:card_not_owned)
      end

      if admiral_card_id &&
           Repo.exists?(
             from f in Fleet,
               where:
                 f.universe_user_id == ^planet.universe_user_id and
                   f.admiral_card_id == ^admiral_card_id,
               lock: "FOR UPDATE"
           ) do
        Repo.rollback(:card_already_assigned)
      end

      fleet_changeset =
        Fleet.changeset(%Fleet{}, %{
          name: name,
          admiral_name: admiral_name,
          admiral_card_id: admiral_card_id,
          universe_id: planet.universe_id,
          universe_user_id: planet.universe_user_id,
          home_planet_id: planet.id,
          status: "idle"
        })

      fleet =
        case Repo.insert(fleet_changeset) do
          {:ok, fleet} ->
            fleet

          {:error, changeset} ->
            if card_already_assigned_error?(changeset) do
              Repo.rollback(:card_already_assigned)
            else
              Repo.rollback(:invalid_fleet)
            end
        end

      :ok = ensure_ship_slots(fleet.id)
      Repo.preload(fleet, [:ships, home_planet: [:solar_system]])
    end)
    |> normalize_transaction_result()
  rescue
    ArgumentError -> {:error, :invalid_fleet}
  end

  @doc """
  Assigns an admiral card from the user's deck to a fleet.
  Returns `{:ok, fleet}` or `{:error, reason}`.

  Reasons: `:not_found` (fleet not owned), `:card_not_owned` (card not in deck).
  """
  def assign_admiral_to_fleet(fleet_id, user_id, card_id) do
    Repo.transaction(fn ->
      fleet =
        Repo.one(
          from f in Fleet,
            join: uu in assoc(f, :universe_user),
            where: f.id == ^fleet_id and uu.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      if is_nil(fleet), do: Repo.rollback(:not_found)

      unless Cards.user_owns_card?(fleet.universe_user_id, card_id) do
        Repo.rollback(:card_not_owned)
      end

      if Repo.exists?(
           from f in Fleet,
             where:
               f.universe_user_id == ^fleet.universe_user_id and
                 f.admiral_card_id == ^card_id and
                 f.id != ^fleet.id,
             lock: "FOR UPDATE"
         ) do
        Repo.rollback(:card_already_assigned)
      end

      case fleet |> Fleet.changeset(%{admiral_card_id: card_id}) |> Repo.update() do
        {:ok, updated_fleet} ->
          updated_fleet

        {:error, changeset} ->
          if card_already_assigned_error?(changeset) do
            Repo.rollback(:card_already_assigned)
          else
            Repo.rollback(:invalid_fleet)
          end
      end
    end)
    |> normalize_transaction_result()
  end

  @doc "Removes the admiral card assignment from a fleet."
  def unassign_admiral_from_fleet(fleet_id, user_id) do
    Repo.transaction(fn ->
      fleet =
        Repo.one(
          from f in Fleet,
            join: uu in assoc(f, :universe_user),
            where: f.id == ^fleet_id and uu.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      if is_nil(fleet), do: Repo.rollback(:not_found)

      fleet
      |> Fleet.changeset(%{admiral_card_id: nil})
      |> Repo.update!()
    end)
    |> normalize_transaction_result()
  end

  @doc "Lists galaxies that still contain valid colonization targets for the fleet."
  def list_colonizable_galaxies_for_fleet(fleet_id, user_id, limit \\ 50) do
    case fleet_for_user(fleet_id, user_id) do
      nil ->
        {:error, :fleet_not_found}

      fleet ->
        galaxies =
          Repo.all(
            from g in Galaxy,
              join: s in assoc(g, :solar_systems),
              join: p in assoc(s, :planets),
              left_join: m in FleetMission,
              on: m.target_planet_id == p.id and m.phase == "colonizing",
              where: g.universe_id == ^fleet.universe_id,
              where:
                p.slot_type == "planet" and is_nil(p.universe_user_id) and
                  p.id != ^fleet.home_planet_id and is_nil(m.id),
              group_by: [g.id, g.number],
              order_by: [asc: g.number],
              limit: ^limit,
              select: %{
                id: g.id,
                number: g.number,
                free_planets: count(p.id)
              }
          )

        {:ok, galaxies}
    end
  end

  @doc "Lists systems inside a galaxy that still contain valid colonization targets."
  def list_colonizable_systems_for_fleet(fleet_id, user_id, galaxy_id, limit \\ 100) do
    case fleet_for_user(fleet_id, user_id) do
      nil ->
        {:error, :fleet_not_found}

      fleet ->
        systems =
          Repo.all(
            from s in SolarSystem,
              join: g in assoc(s, :galaxy),
              join: p in assoc(s, :planets),
              left_join: m in FleetMission,
              on: m.target_planet_id == p.id and m.phase == "colonizing",
              where: g.id == ^galaxy_id and g.universe_id == ^fleet.universe_id,
              where:
                p.slot_type == "planet" and is_nil(p.universe_user_id) and
                  p.id != ^fleet.home_planet_id and is_nil(m.id),
              group_by: [s.id, s.number],
              order_by: [asc: s.number],
              limit: ^limit,
              select: %{
                id: s.id,
                number: s.number,
                free_planets: count(p.id)
              }
          )

        {:ok, systems}
    end
  end

  @doc "Lists colonizable planets inside a system."
  def list_colonizable_planets_for_fleet(fleet_id, user_id, system_id, limit \\ 50) do
    case fleet_for_user(fleet_id, user_id) do
      nil ->
        {:error, :fleet_not_found}

      fleet ->
        planets =
          Repo.all(
            from p in Planet,
              join: s in assoc(p, :solar_system),
              join: g in assoc(s, :galaxy),
              left_join: m in FleetMission,
              on: m.target_planet_id == p.id and m.phase == "colonizing",
              where: s.id == ^system_id and g.universe_id == ^fleet.universe_id,
              where:
                p.slot_type == "planet" and is_nil(p.universe_user_id) and
                  p.id != ^fleet.home_planet_id and is_nil(m.id),
              order_by: [asc: p.orbit_position, asc: p.region],
              limit: ^limit,
              select: %{
                id: p.id,
                name: p.name,
                orbit_position: p.orbit_position,
                region: p.region,
                solar_system_id: s.id,
                solar_system_number: s.number,
                galaxy_id: g.id,
                galaxy_number: g.number
              }
          )

        {:ok, planets}
    end
  end

  @doc "Dispatches a colonization mission for a fleet owned by the user."
  def dispatch_colonization_mission_for_user(fleet_id, user_id, target_planet_id) do
    Repo.transaction(fn ->
      fleet =
        fleet_for_user_for_update(fleet_id, user_id)
        |> Repo.preload([:ships, :home_planet])

      if is_nil(fleet), do: Repo.rollback(:fleet_not_found)
      if fleet.status != "idle", do: Repo.rollback(:fleet_busy)

      origin_planet =
        Repo.one(
          from p in Planet,
            where: p.id == ^fleet.home_planet_id,
            preload: [:solar_system],
            lock: "FOR UPDATE"
        )

      if is_nil(origin_planet), do: Repo.rollback(:origin_not_found)

      origin_planet = refresh_planet_resources!(origin_planet)

      target_planet =
        Repo.one(
          from p in Planet,
            where:
              p.id == ^target_planet_id and
                p.universe_id == ^fleet.universe_id and
                p.slot_type == "planet",
            preload: [:solar_system]
        )

      if is_nil(target_planet), do: Repo.rollback(:target_not_found)
      if origin_planet.id == target_planet.id, do: Repo.rollback(:invalid_target)
      if not is_nil(target_planet.universe_user_id), do: Repo.rollback(:target_unavailable)
      if target_planet_colonizing?(target_planet.id), do: Repo.rollback(:target_colonizing)

      ship_counts = fleet_ship_counts(fleet.ships)

      if Map.get(ship_counts, "colonizer", 0) < 1 do
        Repo.rollback(:colonizer_required)
      end

      route_system_ids =
        resolve_route_ids!(origin_planet.solar_system_id, target_planet.solar_system_id, fleet.universe_id)

      outbound_travel_seconds =
        travel_seconds(route_system_ids, origin_planet.orbit_position, target_planet.orbit_position)

      return_travel_seconds =
        travel_seconds(Enum.reverse(route_system_ids), target_planet.orbit_position, origin_planet.orbit_position)

      colonization_seconds = GameplaySettings.colonization_seconds()

      outbound_fuel_per_s = total_fuel_per_second(ship_counts)
      return_fuel_per_s = ship_counts |> consume_one_colonizer_count() |> total_fuel_per_second()

      hydrogen_cost =
        trunc(
          Float.ceil(
            outbound_fuel_per_s * outbound_travel_seconds +
              return_fuel_per_s * return_travel_seconds
          )
        )

      if origin_planet.hydrogen < hydrogen_cost, do: Repo.rollback(:insufficient_hydrogen)

      origin_planet
      |> Ecto.Changeset.cast(%{hydrogen: origin_planet.hydrogen - hydrogen_cost}, [:hydrogen])
      |> Repo.update!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      outbound_arrival_at = DateTime.add(now, outbound_travel_seconds, :second)

      mission =
        %FleetMission{}
        |> FleetMission.changeset(%{
          mission_type: "colonization",
          phase: "outbound",
          route_system_ids: route_system_ids,
          outbound_travel_seconds: outbound_travel_seconds,
          colonization_seconds: colonization_seconds,
          return_travel_seconds: return_travel_seconds,
          hydrogen_cost: hydrogen_cost,
          outbound_arrival_at: outbound_arrival_at,
          fleet_id: fleet.id,
          origin_planet_id: origin_planet.id,
          target_planet_id: target_planet.id,
          universe_user_id: fleet.universe_user_id,
          universe_id: fleet.universe_id
        })
        |> Repo.insert!()

      update_fleet_status!(fleet.id, "outbound")
      mission = schedule_mission_action!(mission, "arrive", outbound_arrival_at)

      :telemetry.execute(
        [:nexus_downfall, :fleets, :colonization_dispatched],
        %{count: 1},
        %{mission_id: mission.id, fleet_id: fleet.id, target_planet_id: target_planet.id}
      )

      Repo.preload(mission, [:fleet, :origin_planet, :target_planet])
    end)
    |> normalize_transaction_result()
  rescue
    ArgumentError -> {:error, :invalid_dispatch_request}
    Ecto.ConstraintError -> {:error, :fleet_busy}
  end

  @doc "Processes mission transitions triggered by Oban workers."
  def process_mission_transition(mission_id, action) do
    case action do
      "arrive" -> process_mission_arrival(mission_id)
      "complete_colonization" -> process_mission_colonization_completion(mission_id)
      "return" -> process_mission_return(mission_id)
      _ -> :ok
    end
  end

  def get_active_mission_for_fleet(fleet_id) do
    Repo.one(
      from m in FleetMission,
        where: m.fleet_id == ^fleet_id and m.phase in ^@active_mission_phases,
        order_by: [desc: m.inserted_at],
        limit: 1
    )
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
          :noop

        item.status != "building" or is_nil(item.finish_at) ->
          :noop

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

          event_payload = %{
            fleet_id: item.fleet_id,
            ship_type: item.ship_type,
            fleet_ship_quantity: ship_row.quantity + 1,
            planet_id: item.planet_id
          }

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
              {:ok, _scheduled_item} -> {:notify, event_payload}
              {:error, reason} -> Repo.rollback(reason)
            end
          else
            item
            |> ShipyardQueueItem.changeset(%{status: "completed", oban_job_id: nil})
            |> Repo.update!()

            start_next_queue_item!(item.planet_id)
            {:notify, event_payload}
          end
      end
    end)
    |> case do
      {:ok, {:notify, payload}} ->
        :ok = notify_fleet_ship_built(payload)
        :ok

      {:ok, :noop} ->
        :ok

      {:error, reason} -> reason
    end
  end

  defp process_mission_arrival(mission_id) do
    Repo.transaction(fn ->
      mission =
        Repo.one(
          from m in FleetMission,
            where: m.id == ^mission_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(mission) ->
          :noop

        mission.phase != "outbound" ->
          :noop

        true ->
          target_planet =
            Repo.one!(
              from p in Planet,
                where: p.id == ^mission.target_planet_id,
                lock: "FOR UPDATE"
            )

          now = DateTime.utc_now() |> DateTime.truncate(:second)

          cond do
            not is_nil(target_planet.universe_user_id) or
                target_planet_colonizing?(target_planet.id, mission.id) ->
              return_at = DateTime.add(now, mission.return_travel_seconds, :second)

              mission =
                mission
                |> FleetMission.changeset(%{
                  phase: "returning",
                  result_reason: "late_arrival",
                  return_arrival_at: return_at,
                  current_oban_job_id: nil
                })
                |> Repo.update!()

              update_fleet_status!(mission.fleet_id, "returning")
              schedule_mission_action!(mission, "return", return_at)

              :telemetry.execute(
                [:nexus_downfall, :fleets, :colonization_arrival_lost],
                %{count: 1},
                %{mission_id: mission.id, target_planet_id: mission.target_planet_id}
              )

              :ok

            true ->
              complete_at = DateTime.add(now, mission.colonization_seconds, :second)

              mission =
                mission
                |> FleetMission.changeset(%{
                  phase: "colonizing",
                  result_reason: nil,
                  colonization_complete_at: complete_at,
                  current_oban_job_id: nil
                })
                |> Repo.update!()

              update_fleet_status!(mission.fleet_id, "colonizing")
              schedule_mission_action!(mission, "complete_colonization", complete_at)

              :telemetry.execute(
                [:nexus_downfall, :fleets, :colonization_arrival_won],
                %{count: 1},
                %{mission_id: mission.id, target_planet_id: mission.target_planet_id}
              )

              :ok
          end
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:ok, :noop} -> :ok
      {:error, reason} -> reason
    end
  end

  defp process_mission_colonization_completion(mission_id) do
    Repo.transaction(fn ->
      mission =
        Repo.one(
          from m in FleetMission,
            where: m.id == ^mission_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(mission) ->
          :noop

        mission.phase != "colonizing" ->
          :noop

        true ->
          target_planet =
            Repo.one!(
              from p in Planet,
                where: p.id == ^mission.target_planet_id,
                lock: "FOR UPDATE"
            )

          now = DateTime.utc_now() |> DateTime.truncate(:second)

          cond do
            not is_nil(target_planet.universe_user_id) and
                target_planet.universe_user_id != mission.universe_user_id ->
              return_at = DateTime.add(now, mission.return_travel_seconds, :second)

              mission =
                mission
                |> FleetMission.changeset(%{
                  phase: "returning",
                  result_reason: "target_unavailable",
                  return_arrival_at: return_at,
                  current_oban_job_id: nil
                })
                |> Repo.update!()

              update_fleet_status!(mission.fleet_id, "returning")
              schedule_mission_action!(mission, "return", return_at)
              :ok

            true ->
              claimed_planet =
                target_planet
                |> Ecto.Changeset.cast(
                  %{
                    universe_user_id: mission.universe_user_id,
                    name: default_colony_name(target_planet, mission)
                  },
                  [:universe_user_id, :name]
                )
                |> Repo.update!()

              {:ok, _} = Planets.ensure_building_slots(claimed_planet.id)
              :ok = Planets.apply_starter_setup(claimed_planet.id)

              consume_colonizer_from_fleet!(mission.fleet_id)

              remaining_ships =
                Repo.one(
                  from fs in FleetShip,
                    where: fs.fleet_id == ^mission.fleet_id,
                    select: coalesce(sum(fs.quantity), 0)
                ) || 0

              if remaining_ships > 0 do
                return_at = DateTime.add(now, mission.return_travel_seconds, :second)

                mission =
                  mission
                  |> FleetMission.changeset(%{
                    phase: "returning",
                    result_reason: "colonization_success",
                    return_arrival_at: return_at,
                    current_oban_job_id: nil
                  })
                  |> Repo.update!()

                update_fleet_status!(mission.fleet_id, "returning")
                schedule_mission_action!(mission, "return", return_at)
              else
                mission
                |> FleetMission.changeset(%{
                  phase: "completed",
                  result_reason: "colonization_success",
                  completed_at: now,
                  current_oban_job_id: nil
                })
                |> Repo.update!()

                update_fleet_status!(mission.fleet_id, "idle")
              end

              :telemetry.execute(
                [:nexus_downfall, :fleets, :colonization_completed],
                %{count: 1},
                %{mission_id: mission.id, target_planet_id: mission.target_planet_id}
              )

              :ok
          end
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:ok, :noop} -> :ok
      {:error, reason} -> reason
    end
  end

  defp process_mission_return(mission_id) do
    Repo.transaction(fn ->
      mission =
        Repo.one(
          from m in FleetMission,
            where: m.id == ^mission_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(mission) ->
          :noop

        mission.phase != "returning" ->
          :noop

        true ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          mission
          |> FleetMission.changeset(%{
            phase: "completed",
            completed_at: now,
            current_oban_job_id: nil
          })
          |> Repo.update!()

          update_fleet_status!(mission.fleet_id, "idle")

          :telemetry.execute(
            [:nexus_downfall, :fleets, :mission_returned],
            %{count: 1},
            %{mission_id: mission.id, fleet_id: mission.fleet_id}
          )

          :ok
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:ok, :noop} -> :ok
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

  def fleet_updates_topic_for_user(user_id) when is_integer(user_id) do
    "fleet_updates:user:" <> Integer.to_string(user_id)
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

  defp consume_colonizer_from_fleet!(fleet_id) do
    ship =
      Repo.one(
        from fs in FleetShip,
          where: fs.fleet_id == ^fleet_id and fs.ship_type == "colonizer",
          lock: "FOR UPDATE"
      )

    cond do
      is_nil(ship) -> Repo.rollback(:colonizer_missing)
      ship.quantity < 1 -> Repo.rollback(:colonizer_missing)
      true ->
        ship
        |> FleetShip.changeset(%{quantity: ship.quantity - 1})
        |> Repo.update!()
    end
  end

  defp schedule_mission_action!(mission, action, at_datetime) do
    case FleetMissionWorker.new(
           %{"mission_id" => mission.id, "action" => action},
           scheduled_at: at_datetime
         )
         |> Oban.insert() do
      {:ok, job} ->
        mission
        |> FleetMission.changeset(%{current_oban_job_id: job.id})
        |> Repo.update!()

      {:error, _changeset} ->
        Repo.rollback(:mission_scheduling_failed)
    end
  end

  defp update_fleet_status!(fleet_id, status) do
    fleet = Repo.one!(from f in Fleet, where: f.id == ^fleet_id, lock: "FOR UPDATE")

    fleet
    |> Fleet.changeset(%{status: status})
    |> Repo.update!()
  end

  defp fleet_for_user_for_update(fleet_id, user_id) do
    Repo.one(
      from f in Fleet,
        join: uu in assoc(f, :universe_user),
        where: f.id == ^fleet_id and uu.user_id == ^user_id,
        lock: "FOR UPDATE"
    )
  end

  defp fleet_for_user(fleet_id, user_id) do
    Repo.one(
      from f in Fleet,
        join: uu in assoc(f, :universe_user),
        where: f.id == ^fleet_id and uu.user_id == ^user_id
    )
  end

  defp resolve_route_ids!(origin_system_id, target_system_id, universe_id) do
    topology = universe_topology(universe_id)

    case Pathfinder.shortest_path(topology.systems, topology.hyperlinks, origin_system_id, target_system_id) do
      {:ok, route} -> route
      {:error, :no_route} -> Repo.rollback(:no_route)
      {:error, :unknown_system} -> Repo.rollback(:unknown_system)
    end
  end

  defp universe_topology(universe_id) do
    key = {__MODULE__, :topology, universe_id}

    case :persistent_term.get(key, :undefined) do
      :undefined ->
        topology = load_universe_topology(universe_id)
        :persistent_term.put(key, topology)
        topology

      topology ->
        topology
    end
  end

  defp load_universe_topology(universe_id) do
    systems =
      Repo.all(
        from s in SolarSystem,
          join: g in assoc(s, :galaxy),
          where: g.universe_id == ^universe_id,
          select: %{id: s.id, x: s.x, y: s.y}
      )

    hyperlinks =
      Repo.all(
        from h in Hyperlink,
          join: sa in SolarSystem,
          on: sa.id == h.system_a_id,
          join: ga in assoc(sa, :galaxy),
          where: ga.universe_id == ^universe_id,
          select: %{system_a_id: h.system_a_id, system_b_id: h.system_b_id}
      )

    %{systems: systems, hyperlinks: hyperlinks}
  end

  defp travel_seconds(route_system_ids, origin_orbit_position, target_orbit_position) do
    hops = max(length(route_system_ids) - 1, 0)
    orbit_distance = abs(target_orbit_position - origin_orbit_position)
    travel = GameplaySettings.travel_settings()

    launch = Map.get(travel, "launch_seconds", 0)
    landing = Map.get(travel, "landing_seconds", 0)
    per_hop = Map.get(travel, "seconds_per_hyperlink_hop", 0)
    per_orbit = Map.get(travel, "seconds_per_orbit_step", 0)

    launch + landing + hops * per_hop + orbit_distance * per_orbit
  end

  defp fleet_ship_counts(ships) do
    Enum.reduce(ships, %{}, fn ship, acc ->
      Map.put(acc, ship.ship_type, ship.quantity)
    end)
  end

  defp consume_one_colonizer_count(ship_counts) do
    Map.update(ship_counts, "colonizer", 0, fn quantity -> max(quantity - 1, 0) end)
  end

  defp total_fuel_per_second(ship_counts) do
    Enum.reduce(ship_counts, 0.0, fn {ship_type, quantity}, acc ->
      case ship_definition(ship_type) do
        nil -> acc
        ship -> acc + quantity * ship.fuel_per_s
      end
    end)
  end

  defp target_planet_colonizing?(target_planet_id, exclude_mission_id \\ nil) do
    query =
      from m in FleetMission,
        where: m.target_planet_id == ^target_planet_id and m.phase == "colonizing",
        lock: "FOR UPDATE"

    query =
      if is_nil(exclude_mission_id) do
        query
      else
        from m in query, where: m.id != ^exclude_mission_id
      end

    Repo.exists?(query)
  end

  defp default_colony_name(planet, mission) do
    case String.trim(planet.name || "") do
      "" -> "Colony #{mission.universe_user_id}-#{planet.id}"
      existing -> existing
    end
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

  defp notify_fleet_ship_built(payload) do
    user_id =
      Repo.one(
        from uu in NexusDownfall.Accounts.UniverseUser,
          join: f in Fleet,
          on: f.universe_user_id == uu.id,
          where: f.id == ^payload.fleet_id,
          select: uu.user_id
      )

    if is_integer(user_id) do
      Phoenix.PubSub.broadcast(
        NexusDownfall.PubSub,
        fleet_updates_topic_for_user(user_id),
        {:fleet_ship_built, payload}
      )
    end

    :ok
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

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil
  defp parse_optional_int(value), do: parse_int!(value)

  defp normalize_transaction_result({:ok, value}), do: {:ok, value}
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}

  defp card_already_assigned_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {:admiral_card_id, {"card_already_assigned", _opts}} -> true
      _ -> false
    end)
  end
end
