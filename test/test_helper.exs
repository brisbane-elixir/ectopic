ExUnit.start

Mix.Task.run "ecto.create", ~w(-r Ectopic.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Ectopic.Repo --quiet)
Ecto.Adapters.SQL.Sandbox.mode(Ectopic.Repo, :manual)
