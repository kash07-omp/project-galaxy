import Ecto.Query
alias NexusDownfall.Repo
alias NexusDownfall.Fleets.FleetMission
alias Oban.Job

active = Repo.aggregate(from(m in FleetMission, where: m.phase in ["outbound","colonizing","returning"]), :count, :id)
discarded_arrive = Repo.aggregate(from(j in Job, where: j.worker == "NexusDownfall.Workers.FleetMissionWorker" and j.state == "discarded" and fragment("(?->>'action') = 'arrive'", j.args)), :count, :id)
IO.puts("active_missions=#{active}")
IO.puts("discarded_arrive_jobs=#{discarded_arrive}")
