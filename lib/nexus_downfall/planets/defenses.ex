defmodule NexusDownfall.Planets.Defenses do
  @moduledoc """
  Planetary defense construction and catalog rules.

  Defense construction mirrors shipyard queue semantics but stores fixed
  defenses directly on the planet. Combat resolution will consume this catalog
  in later Phase 4 tasks.
  """

  import Ecto.Query

  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Defense, DefenseQueueItem, Planet, ProductionEngine}
  alias NexusDownfall.Repo
  alias NexusDownfall.Workers.DefenseConstructionCompleteWorker

  @defense_catalog %{
    "missile_platform" => %{
      type: "missile_platform",
      tier: 1,
      role: "Cheap anti-light defense",
      name: "Missile Platform",
      description:
        "Cheap mass defense that punishes light fighters, corvettes and unescorted freighters.",
      hull: 160,
      shield: 15,
      attack: 55,
      accuracy: 55,
      energy: 1,
      cost: %{raw_materials: 1_800, microchips: 300, hydrogen: 0},
      build_time_seconds: 60,
      target_priority: ["Light", "Civil", "Medium"],
      rules: ["Fixed Defense", "Saturation Fire"]
    },
    "light_laser_tower" => %{
      type: "light_laser_tower",
      tier: 1,
      role: "Precise anti-light defense",
      name: "Light Laser Tower",
      description: "Accurate turret built to stop agile raiders and fast early fleets.",
      hull: 180,
      shield: 25,
      attack: 75,
      accuracy: 75,
      energy: 2,
      cost: %{raw_materials: 1_500, microchips: 900, hydrogen: 0},
      build_time_seconds: 75,
      target_priority: ["Light", "Medium", "Civil"],
      rules: ["Fixed Defense", "Anti-squadron Accuracy"]
    },
    "heavy_laser_tower" => %{
      type: "heavy_laser_tower",
      tier: 2,
      role: "Anti-medium defense",
      name: "Heavy Laser Tower",
      description: "The natural counter to frigates, heavy fighters and missile corvettes.",
      hull: 620,
      shield: 90,
      attack: 220,
      accuracy: 68,
      energy: 5,
      cost: %{raw_materials: 5_000, microchips: 3_000, hydrogen: 0},
      build_time_seconds: 180,
      target_priority: ["Medium", "Light", "Heavy"],
      rules: ["Fixed Defense", "Anti-squadron Accuracy"]
    },
    "gauss_cannon" => %{
      type: "gauss_cannon",
      tier: 2,
      role: "Heavy armor piercing",
      name: "Gauss Cannon",
      description:
        "High-impact defense for cruisers, bombers, blockers and expensive heavy ships.",
      hull: 1_800,
      shield: 120,
      attack: 700,
      accuracy: 52,
      energy: 8,
      cost: %{raw_materials: 20_000, microchips: 14_000, hydrogen: 2_000},
      build_time_seconds: 600,
      target_priority: ["Heavy", "Capital", "Medium"],
      rules: ["Fixed Defense", "Piercing Shot"]
    },
    "ion_cannon" => %{
      type: "ion_cannon",
      tier: 2,
      role: "Shield suppression",
      name: "Ion Cannon",
      description:
        "Support defense that weakens enemy shields so Gauss and Plasma batteries can finish the target.",
      hull: 900,
      shield: 500,
      attack: 90,
      accuracy: 78,
      energy: 10,
      cost: %{raw_materials: 5_000, microchips: 12_000, hydrogen: 2_000},
      build_time_seconds: 480,
      target_priority: ["Heavy", "Capital", "Support"],
      rules: ["Fixed Defense", "Ion Pulse"]
    },
    "plasma_turret" => %{
      type: "plasma_turret",
      tier: 3,
      role: "Anti-capital defense",
      name: "Plasma Turret",
      description:
        "Expensive, slow and lethal battery against capital ships and hardened orbital targets.",
      hull: 6_000,
      shield: 500,
      attack: 2_500,
      accuracy: 50,
      energy: 20,
      cost: %{raw_materials: 60_000, microchips: 55_000, hydrogen: 30_000},
      build_time_seconds: 1_800,
      target_priority: ["Capital", "Heavy", "Siege"],
      rules: ["Fixed Defense", "Piercing Shot"]
    },
    "planetary_shield_dome" => %{
      type: "planetary_shield_dome",
      tier: 3,
      role: "Global protection",
      name: "Planetary Shield Dome",
      description:
        "Strategic shield infrastructure that absorbs damage before other defenses collapse.",
      hull: 25_000,
      shield: 15_000,
      attack: 0,
      accuracy: 0,
      energy: 60,
      cost: %{raw_materials: 80_000, microchips: 100_000, hydrogen: 25_000},
      build_time_seconds: 2_400,
      max_per_planet: 1,
      target_priority: [],
      rules: ["Fixed Defense", "Shield Overload", "Critical Infrastructure"]
    },
    "anti_siege_matrix" => %{
      type: "anti_siege_matrix",
      tier: 3,
      role: "Bombardment counter",
      name: "Anti-siege Matrix",
      description:
        "Specialized orbital interception grid that reduces bombardment pressure from bombers and Aphelion platforms.",
      hull: 2_500,
      shield: 800,
      attack: 300,
      accuracy: 85,
      energy: 30,
      cost: %{raw_materials: 35_000, microchips: 60_000, hydrogen: 20_000},
      build_time_seconds: 1_500,
      max_per_planet: 3,
      target_priority: ["Siege", "Capital", "Heavy"],
      rules: ["Fixed Defense", "Anti-siege", "Orbital Interception"]
    },
    "orbital_interdiction_platform" => %{
      type: "orbital_interdiction_platform",
      tier: 3,
      role: "Blockade counter",
      name: "Orbital Interdiction Platform",
      description:
        "Planetary countermeasure against blockers, slow support craft and heavy logistical ships.",
      hull: 4_500,
      shield: 1_200,
      attack: 450,
      accuracy: 65,
      energy: 45,
      cost: %{raw_materials: 75_000, microchips: 110_000, hydrogen: 60_000},
      build_time_seconds: 2_600,
      target_priority: ["Support", "Heavy", "Civil"],
      rules: ["Fixed Defense", "Anti-blockade", "Orbital Interception"]
    },
    "planetary_defense_bastion" => %{
      type: "planetary_defense_bastion",
      tier: 3,
      role: "Anti-conquest infrastructure",
      name: "Planetary Defense Bastion",
      description:
        "Critical hardpoint that raises planetary conquest resistance against Exodus-class operations.",
      hull: 15_000,
      shield: 1_000,
      attack: 150,
      accuracy: 40,
      energy: 15,
      cost: %{raw_materials: 120_000, microchips: 80_000, hydrogen: 40_000},
      build_time_seconds: 3_000,
      max_per_planet: 1,
      target_priority: ["Conquest", "Civil", "Heavy"],
      rules: ["Fixed Defense", "Conquest Resistance", "Critical Infrastructure"]
    }
  }

  def defense_catalog do
    @defense_catalog
    |> Map.values()
    |> Enum.sort_by(&{&1.tier, &1.name})
  end

  def defense_definition(type), do: Map.get(@defense_catalog, type)

  def defense_build_time_seconds(type, quantity \\ 1) do
    case defense_definition(type) do
      %{build_time_seconds: base} -> base * quantity
      _ -> 0
    end
  end

  def defense_total_cost(type, quantity \\ 1) do
    case defense_definition(type) do
      %{cost: cost} -> Map.new(cost, fn {resource, amount} -> {resource, amount * quantity} end)
      _ -> %{}
    end
  end

  def defense_panel_for_user_planet(planet_id, user_id) do
    planet = owned_planet!(planet_id, user_id)
    {:ok, defenses} = ensure_defense_slots(planet.id)

    %{
      defenses: defenses,
      queue_items: list_defense_queue(planet.id),
      defense_catalog: defense_catalog()
    }
  end

  def list_planet_defenses(planet_id) do
    Repo.all(
      from d in Defense,
        where: d.planet_id == ^planet_id,
        order_by: d.defense_type
    )
  end

  def list_defense_queue(planet_id) do
    Repo.all(
      from q in DefenseQueueItem,
        where: q.planet_id == ^planet_id and q.status in ["queued", "building"],
        order_by: [asc: q.queue_position]
    )
  end

  def ensure_defense_slots(planet_id) do
    existing_types =
      Repo.all(from d in Defense, where: d.planet_id == ^planet_id, select: d.defense_type)

    missing = Defense.defense_types() -- existing_types

    results =
      Enum.map(missing, fn type ->
        %Defense{}
        |> Defense.changeset(%{
          planet_id: planet_id,
          defense_type: type,
          quantity: 0,
          damaged_quantity: 0
        })
        |> Repo.insert(on_conflict: :nothing)
      end)

    errors = Enum.filter(results, fn {tag, _} -> tag == :error end)

    if errors == [] do
      {:ok, list_planet_defenses(planet_id)}
    else
      {:error, errors}
    end
  end

  def enqueue_defense_construction_for_user(planet_id, user_id, attrs) do
    Repo.transaction(fn ->
      defense_type = Map.get(attrs, "defense_type") || Map.get(attrs, :defense_type)
      quantity = parse_int!(Map.get(attrs, "quantity") || Map.get(attrs, :quantity) || 1)

      if quantity <= 0, do: Repo.rollback(:invalid_quantity)

      defense = defense_definition(defense_type)
      if is_nil(defense), do: Repo.rollback(:unknown_defense)

      planet =
        owned_planet_for_update!(planet_id, user_id)
        |> refresh_planet_resources!()

      {:ok, _} = ensure_defense_slots(planet.id)
      buildings = Planets.list_buildings(planet.id)
      defense_center = Enum.find(buildings, &(&1.type == "defense_center")) || %Building{level: 0}

      if defense_center.level < 1, do: Repo.rollback(:defense_center_required)

      enforce_defense_limit!(planet.id, defense, quantity)

      total_cost = defense_total_cost(defense_type, quantity)

      unless ProductionEngine.can_afford?(planet, total_cost) do
        Repo.rollback(:insufficient_resources)
      end

      planet
      |> Ecto.Changeset.cast(
        ProductionEngine.deduct_cost(planet, total_cost),
        Map.keys(total_cost)
      )
      |> Repo.update!()

      next_position =
        (Repo.one(
           from q in DefenseQueueItem,
             where: q.planet_id == ^planet.id,
             order_by: [desc: q.queue_position],
             select: q.queue_position,
             limit: 1,
             lock: "FOR UPDATE"
         ) || 0) + 1

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      build_seconds = defense_build_time_seconds(defense_type)

      has_active =
        Repo.exists?(
          from q in DefenseQueueItem,
            where: q.planet_id == ^planet.id and q.status == "building"
        )

      item =
        %DefenseQueueItem{}
        |> DefenseQueueItem.changeset(%{
          planet_id: planet.id,
          defense_type: defense_type,
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
        [:nexus_downfall, :planets, :defense_queued],
        %{count: quantity},
        %{planet_id: planet.id, defense_type: defense_type}
      )

      item
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
          from q in DefenseQueueItem,
            where: q.id == ^queue_item_id,
            lock: "FOR UPDATE"
        )

      cond do
        is_nil(item) ->
          :noop

        item.status != "building" or is_nil(item.finish_at) ->
          :noop

        true ->
          {:ok, _} = ensure_defense_slots(item.planet_id)

          defense_row =
            Repo.one!(
              from d in Defense,
                where: d.planet_id == ^item.planet_id and d.defense_type == ^item.defense_type,
                lock: "FOR UPDATE"
            )

          defense_row
          |> Defense.changeset(%{quantity: defense_row.quantity + 1})
          |> Repo.update!()

          :telemetry.execute(
            [:nexus_downfall, :planets, :defense_construction_completed],
            %{count: 1},
            %{planet_id: item.planet_id, defense_type: item.defense_type}
          )

          event_payload = %{
            planet_id: item.planet_id,
            defense_type: item.defense_type,
            defense_quantity: defense_row.quantity + 1
          }

          if item.quantity > 1 do
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            next_cycle_item =
              item
              |> DefenseQueueItem.changeset(%{
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
            |> DefenseQueueItem.changeset(%{status: "completed", oban_job_id: nil})
            |> Repo.update!()

            start_next_queue_item!(item.planet_id)
            {:notify, event_payload}
          end
      end
    end)
    |> case do
      {:ok, {:notify, payload}} ->
        :ok = notify_defense_built(payload)
        :ok

      {:ok, :noop} ->
        :ok

      {:error, reason} ->
        reason
    end
  end

  def defense_updates_topic_for_user(user_id) when is_integer(user_id) do
    "defense_updates:user:" <> Integer.to_string(user_id)
  end

  defp enforce_defense_limit!(planet_id, %{max_per_planet: max, type: defense_type}, quantity)
       when is_integer(max) do
    existing =
      Repo.one(
        from d in Defense,
          where: d.planet_id == ^planet_id and d.defense_type == ^defense_type,
          select: d.quantity,
          lock: "FOR UPDATE"
      ) || 0

    queued =
      Repo.all(
        from q in DefenseQueueItem,
          where:
            q.planet_id == ^planet_id and q.defense_type == ^defense_type and
              q.status in ["queued", "building"],
          select: q.quantity,
          lock: "FOR UPDATE"
      )
      |> Enum.sum()

    if existing + queued + quantity > max do
      Repo.rollback(:defense_limit_reached)
    end

    :ok
  end

  defp enforce_defense_limit!(_planet_id, _defense, _quantity), do: :ok

  defp start_next_queue_item!(planet_id) do
    next_item =
      Repo.one(
        from q in DefenseQueueItem,
          where: q.planet_id == ^planet_id and q.status == "queued",
          order_by: [asc: q.queue_position],
          limit: 1,
          lock: "FOR UPDATE"
      )

    if next_item do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      started_item =
        next_item
        |> DefenseQueueItem.changeset(%{
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
    case DefenseConstructionCompleteWorker.new(
           %{"queue_item_id" => item.id},
           scheduled_at: item.finish_at
         )
         |> Oban.insert() do
      {:ok, job} ->
        updated_item =
          item
          |> DefenseQueueItem.changeset(%{oban_job_id: job.id})
          |> Repo.update!()

        {:ok, updated_item}

      {:error, _changeset} ->
        {:error, :queue_scheduling_failed}
    end
  end

  defp notify_defense_built(payload) do
    user_id =
      Repo.one(
        from uu in NexusDownfall.Accounts.UniverseUser,
          join: p in Planet,
          on: p.universe_user_id == uu.id,
          where: p.id == ^payload.planet_id,
          select: uu.user_id
      )

    if is_integer(user_id) do
      Phoenix.PubSub.broadcast(
        NexusDownfall.PubSub,
        defense_updates_topic_for_user(user_id),
        {:defense_built, payload}
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

  defp parse_int!(value) when is_integer(value), do: value
  defp parse_int!(value) when is_binary(value), do: String.to_integer(value)

  defp normalize_transaction_result({:ok, value}), do: {:ok, value}
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}
end
