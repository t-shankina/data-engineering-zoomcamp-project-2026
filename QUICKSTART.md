# AIS Data Analytics - Quick Start

## Prerequisites

Before starting, ensure you have the following installed and configured:

### Required Software

- **Docker** (20.10+) and **Docker Compose** (2.0+)
  - Required for running all services (ClickHouse, Airflow, Grafana, Redpanda)
- **Python** (3.10+)
  - Required for producer and dbt transformations
- **uv** (Python package manager)
  - Required for installing all listed dependencies
- **make**
  - Required for using Makefile commands (usually pre-installed on Linux/macOS, install via package manager on Windows)

### API Access

- **AIS Stream API Key**
  - Register at [aisstream.io](https://aisstream.io) and get your API key
  - Required for receiving real-time AIS data

### System Requirements

- **Minimum 8GB RAM**
  - Required for running Docker containers
- **Free disk space: ~10GB**
  - For Docker images and data storage
- **Available ports:**
  - `8080` - Airflow web UI
  - `8123` - ClickHouse HTTP API
  - `9092` - Redpanda/Kafka
  - `3000` - Grafana web UI

### Network

- **Internet connection**
  - Required for pulling Docker images and dependencies, streaming AIS data

## Step-by-Step Setup

### 0. Create `.env` file

```bash
make init
# Edit .env and fill in required values
```

This command creates `.env` from `.env.example` template.  
**Required fields:**

- `AISSTREAMIO_API_KEY` - API key from aisstream.io
- `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` - ClickHouse credentials
- `POSTGRES_USER` / `POSTGRES_PASSWORD` - Postgres credentials
- `AIRFLOW_ADMIN_`* - Airflow login credentials
- `GRAFANA_USER` / `GRAFANA_PASSWORD` - Grafana credentials

### 1. Build images

```bash
make build
```

Builds Docker images for all services.  

### 2. Start infrastructure

```bash
make up
```

Starts all services in the correct order.  
Services will start automatically:

```
Redpanda → redpanda-init → ClickHouse → Postgres → Airflow → Grafana
```

**Service URLs:**

- ClickHouse: `http://localhost:8123` (HTTP API for queries)
- Airflow: `http://localhost:8080` (scheduler web interface)
- Grafana: `http://localhost:3000` (dashboards and visualization)

This may take several minutes on first run.

### 3. Install dependencies

```bash
make deps
```

Installs Python packages via `uv sync`.  
Required for producer and dbt.

### 4. Start producer

NOTE: Run the command below in a new terminal:

```bash
ea
```

*Press Ctrl+C to stop*

The producer:

- Connects to aisstream.io API via WebSocket
- Receives real-time AIS messages from ships
- Sends them to Redpanda (Kafka) topic `ais_data`
- ClickHouse automatically reads from the topic and saves to `position_reports` table

Keep the producer running in this terminal.

### 5. Check ClickHouse data

```bash
make check-clickhouse
```

Checks:

- ClickHouse connection
- Number of records in `position_reports` table

### 6. Run dbt (optional)

```bash
make dbt-run
```

dbt will execute transformations:

- Create aggregated tables
- Apply all models from `models/`
- Results will be available for visualization

**Note:** Going forward, dbt will run automatically via Airflow DAG.

### 7. Enable Airflow DAG

```bash
# Open UI:
make airflow-ui
# → http://localhost:8080
# → Enable DAG: ais_dbt_transformations
```

After enabling the DAG:

- Will run automatically on schedule
- Executes `dbt run` to refresh transformations
- View run history and logs in UI

### 8. Open Grafana

```bash
make grafana-ui
# → http://localhost:3000
# → Dashboard → AIS Data Analysis (test)
```

In Grafana:

- ClickHouse data source already configured
- Dashboard with AIS data visualization imported
- Shows maps, traffic graphs, ship statistics

### 9. Tear down

1. Press Ctrl+C to stop producer
2. Stop services, remove artifacts

```bash
make clean
```

---

## Common Commands

```bash
make help              # Show all available commands
make status            # Show status of all services
```

**Additional commands:**

```bash
make airflow-ui        # Show Airflow URL and credentials
make grafana-ui        # Show Grafana URL and credentials
```

---

## Troubleshooting

### ClickHouse not receiving data

```bash
# Check status of all services:
make status

# Check record count:
make check-clickhouse
```

**Possible causes:**

- Producer not running → `make producer`
- Invalid API key in `.env` → check `AISSTREAMIO_API_KEY`
- Redpanda not running → `make status`

### Restart Docker containers

1. Press Ctrl+C to stop producer
2. Restart services

```bash
make down              # Stop all
make up                # Start again
```

Or full reload with data cleanup:

```bash
make clean             # Stop + clean artifacts
make build             # Rebuild images (if needed)
make up                # Start
```

1. Start streaming messages again (in a new terminal)

```bash
make producer          # Start streaming messages again
```

### Port conflicts

If ports are occupied by other applications:

- `8080` - Airflow
- `8123` - ClickHouse
- `9092` - Redpanda/Kafka
- `3000` - Grafana

Stop conflicting applications or change ports in `docker-compose.yml`.