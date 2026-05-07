alias NexusDownfall.Repo
alias NexusDownfall.Universe.SolarSystem
alias NexusDownfall.Universe.Hyperlink
alias NexusDownfall.Planets.Planet

import Ecto.Query

systems = Repo.all(from s in SolarSystem, order_by: s.number)

Enum.each(systems, fn s ->
  IO.puts("sys #{s.number} x=#{Float.round(s.x, 1)} y=#{Float.round(s.y, 1)}")
end)

IO.puts("Total systems: #{length(systems)}")
IO.puts("Total planets: #{Repo.aggregate(Planet, :count)}")
IO.puts("Total hyperlinks: #{Repo.aggregate(Hyperlink, :count)}")
