defmodule Archethic.Telemetry do
  @moduledoc false

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    [
      {TelemetryMetricsPrometheus.Core, [metrics: metrics()]}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end

  def metrics do
    [
      # VM
      last_value("vm.memory.atom", unit: :byte),
      last_value("vm.memory.atom_used", unit: :byte),
      last_value("vm.memory.binary", unit: :byte),
      last_value("vm.memory.code", unit: :byte),
      last_value("vm.memory.ets", unit: :byte),
      last_value("vm.memory.processes", unit: :byte),
      last_value("vm.memory.processes_used", unit: :byte),
      last_value("vm.memory.system", unit: :byte),
      last_value("vm.memory.total", unit: :byte),
      #
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),
      last_value("vm.system_counts.process_count"),
      #
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      # Archethic
      distribution("archethic.election.validation_nodes.duration",
        unit: {:native, :second},
        tags: [:nb_nodes],
        measurement: :duration,
        reporter_options: [
          buckets: [10, 100, 500, 1000, 1500, 2000]
        ]
      ),
      distribution("archethic.election.storage_nodes.duration",
        unit: {:native, :millisecond},
        tags: [:nb_nodes],
        measurement: :duration,
        reporter_options: [
          buckets: [10, 100, 500, 1000, 1500, 2000]
        ]
      ),
      distribution("archethic.mining.proof_of_work.duration",
        unit: {:native, :second},
        tags: [:nb_keys],
        measurement: :duration,
        reporter_options: [
          buckets: [10, 100, 500, 1000, 1500, 2000]
        ]
      ),
      distribution(
        "archethic.mining.pending_transaction_validation.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [10, 50, 100, 200, 500, 1000, 2000, 5000]
        ]
      ),
      distribution("archethic.mining.fetch_context.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [10, 50, 100, 200, 500, 1000, 2000, 5000]
        ]
      ),
      distribution(
        "archethic.mining.full_transaction_validation.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [100, 200, 500, 700, 1000, 1500, 2000, 3000, 5000]
        ]
      ),
      distribution("archethic.contract.parsing.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [10, 100, 500, 1000, 1500, 2000]
        ]
      ),
      distribution(
        "archethic.transaction_end_to_end_validation.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [100, 200, 500, 700, 1000, 1500, 2000, 3000, 5000]
        ]
      ),
      distribution("archethic.p2p.send_message.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [10, 50, 100, 200, 300, 500, 700, 900, 1000, 1500, 2000, 3000]
        ],
        tags: [:message]
      ),
      distribution("archethic.p2p.handle_message.duration",
        unit: {:native, :second},
        measurement: :duration,
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 0.8, 1.0, 1.25, 1.5, 2.0]],
        tags: [:message]
      ),
      distribution("archethic.p2p.encode_message.duration",
        unit: {:native, :second},
        measurement: :duration,
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 0.8, 1.0, 1.25, 1.5, 2.0]],
        tags: [:message]
      ),
      distribution("archethic.p2p.decode_message.duration",
        unit: {:native, :second},
        measurement: :duration,
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 0.8, 1.0, 1.25, 1.5, 2.0]],
        tags: [:message]
      ),
      distribution("archethic.p2p.transport_sending.duration",
        unit: {:native, :second},
        measurement: :duration,
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 0.8, 1.0, 1.25, 1.5, 2.0]],
        tags: [:message]
      ),
      distribution("archethic.crypto.tpm_sign.duration",
        unit: {:native, :millisecond},
        measurement: :duration,
        reporter_options: [
          buckets: [10, 50, 100, 200, 300, 500, 700, 900, 1000, 1500, 2000, 3000]
        ]
      ),
      distribution("archethic.crypto.libsodium.duration",
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1.5, 2, 5, 10]],
        measurement: :duration
      ),
      distribution("archethic.crypto.encrypt.duration",
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1.5, 2, 5, 10]],
        measurement: :duration
      ),
      distribution("archethic.crypto.decrypt.duration",
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1.5, 2, 5, 10]],
        measurement: :duration
      ),
      distribution("archethic.replication.validation.duration",
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [100, 200, 500, 700, 1000, 1500, 2000, 3000, 5000]
        ],
        measurement: :duration
      ),
      distribution("archethic.replication.validation.full_write",
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [100, 200, 500, 700, 1000, 1500, 2000, 3000, 5000]
        ],
        measurement: :duration
      ),
      distribution("archethic.db.duration",
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [50, 100, 200, 500, 700, 1000]
        ],
        measurement: :duration,
        tags: [:query]
      ),
      last_value("archethic.self_repair.duration",
        unit: {:native, :millisecond},
        measurement: :duration
      ),
      distribution("archethic.self_repair.process_aggregate.duration",
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1.5, 2, 5, 10]],
        measurement: :duration,
        tags: [:nb_transactions]
      ),
      distribution("archethic.self_repair.summaries_fetch.duration",
        unit: {:native, :second},
        reporter_options: [buckets: [0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1.5, 2, 5, 10]],
        measurement: :duration,
        tags: [:nb_summaries]
      )
    ]
  end
end
