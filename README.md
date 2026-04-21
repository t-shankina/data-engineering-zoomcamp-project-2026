<!-- badges -->
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Kafka](https://img.shields.io/badge/Redpanda-v25.3-231F20?logo=apachekafka&logoColor=white)
![ClickHouse](https://img.shields.io/badge/ClickHouse-26.2-E25A1C?logo=apachespark&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-clickhouse-1.10-FF694B?logo=dbt&logoColor=white)
![Airflow](https://img.shields.io/badge/Apache_Airflow-3.2-017CEE?logo=apacheairflow&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboard-4285F4?logo=looker&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose_v2-2496ED?logo=docker&logoColor=white)

# AIS Data Analytics Pipeline

**DataTalksClub Data Engineering Zoomcamp — Final Project**

A batch + streaming data pipeline that ingests AIS data stream into ClickHouse, transforms it and provides near real-time metrics in Grafana dashboard.

---

## Table of Contents

- [Problem Description](#problem-description)
- [Architecture](#architecture)
- [Technologies Used](#technologies-used)
  - [Cloud & Infrastructure](#cloud--infrastructure)
  - [Data Ingestion](#data-ingestion)
  - [Data Warehouse](#data-warehouse)
  - [Transformations](#transformations)
  - [Orchestration](#orchestration)
  - [Visualization](#visualization)
- [Dashboard](#dashboard)
- [Project Structure](#project-structure)
- [Reproducibility](#reproducibility)
- [License](#license)

---

## Problem Description

**Automatic Identification System (AIS)** is a maritime tracking system that ships use to broadcast their position, speed, course, and other navigational data. This system was originally designed for collision avoidance and maritime safety, but AIS data has become invaluable for various analytical applications.

### What is AIS Data?

AIS transponders on vessels automatically broadcast messages at regular intervals via a VHF transmitter built into the transceiver. These messages are transmitted every 2-10 seconds for ships in motion and every 3 minutes for ships at anchor, creating a continuous stream of high-frequency positional data.

### Why Analyze AIS Data?

AIS data enables powerful insights across multiple domains:

**Maritime Operations & Safety:**
- Real-time vessel tracking and fleet management
- Collision risk assessment and maritime traffic monitoring
- Search and rescue operations coordination
- Port congestion analysis and berth optimization

**Supply Chain & Logistics:**
- Shipping route optimization and ETA predictions
- Container ship tracking for cargo visibility
- Port activity monitoring and throughput analysis
- Global trade flow analysis

**Environmental Monitoring:**
- Illegal fishing detection in protected areas
- Emission tracking and environmental compliance
- Marine protected area violations
- Vessel speed compliance in whale protection zones

**Data Analytics & Research:**
- Maritime traffic patterns and seasonal trends
- Economic activity indicators (trade flows)
- Behavioral analysis of different vessel types
- Machine learning models for anomaly detection

---

## Architecture

The pipeline follows a modern streaming data architecture with the following components:

```
┌─────────────────┐
│  AISStream.io   │  Real-time AIS WebSocket API
│   (WebSocket)   │
└────────┬────────┘
         │ Stream
         ▼
┌─────────────────┐
│ Python Producer │  Consumes WebSocket, publishes to Kafka
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Redpanda/Kafka │  Message broker (topic: ais_data)
│    (Topic)      │
└────────┬────────┘
         │ Stream
         ▼
┌─────────────────┐
│   ClickHouse    │  Analytical data warehouse
│  Kafka Engine   │  - Kafka consumer via materialized view
│  + ReplacingMT  │  - Partitioned by month (YYYY-MM)
│                 │  - Ordered by (user_id, produced_at)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   dbt (models)  │  Data transformations
│   - staging     │  - stg_position_reports (filtered & cleaned)
│   - marts       │  - vessel_activity (hourly aggregations)
│                 │  - vessel_last_position (latest positions)
└────────┬────────┘
         │ Scheduled
         ▼
┌─────────────────┐
│  Apache Airflow │  Workflow orchestration
│   (LocalExec)   │  - Scheduled dbt runs
│                 │  - PostgreSQL metadata DB
└─────────────────┘
         │
         ▼
┌─────────────────┐
│    Grafana      │  Dashboard & visualization
│  (ClickHouse    │  - Real-time vessel maps
│   datasource)   │  - Traffic patterns
│                 │
└─────────────────┘
```

### Data Flow

1. **Real-time Ingestion:** Python producer connects to AISStream.io WebSocket API and receives live AIS position reports
2. **Message Streaming:** Messages are published to Redpanda (Kafka-compatible) topic `ais_data`
3. **Stream Processing:** ClickHouse Kafka Engine table continuously consumes from the topic
4. **Storage:** Materialized view inserts data into partitioned `position_reports` table
5. **Transformation:** dbt models run on schedule (via Airflow) to create analytical tables
6. **Visualization:** Grafana dashboards query ClickHouse for near real-time analytics

### Key Design Decisions

**Why Redpanda?**
- Kafka-compatible, but simpler to deploy (no ZooKeeper)
- Lower resource footprint (perfect for local development)
- Wire-compatible with Kafka clients

**Why ClickHouse?**
- Optimized for analytical queries (OLAP)
- Native Kafka integration via Kafka Engine
- Excellent compression (10x+ for time-series data)
- Fast aggregation queries for dashboards
- Partitioning by month enables efficient data lifecycle management (TTL)

**Why dbt?**
- SQL-based transformations (familiar to analysts)
- Incremental models minimize reprocessing
- Built-in testing and documentation
- Version control for transformation logic

**Why Airflow?**
- Industry-standard orchestration tool
- Rich UI for monitoring and debugging
- Extensible (custom operators for dbt, sensors, etc.)
- Handles retries, alerting, and dependency management

---

## Technologies Used

### Cloud & Infrastructure

**Technology:** Infrastructure as Code

**Components:**
1. **Docker Compose**
- All services defined declaratively in `docker-compose.yml`
- Environment variables managed via `.env` file

**Note:** While this project runs locally for development, it follows cloud-native patterns and can be easily adapted to cloud deployment using managed services

### Data Ingestion

**Technology:** Real-time streaming with WebSocket → Kafka → ClickHouse

**Components:**
1. **Python Producer** (`streaming/producer.py`):
   - Connects to AISStream.io WebSocket API
   - Receives real-time AIS position reports
   - Publishes to Kafka topic `ais_data` with minimal latency

2. **Redpanda (Kafka):**
   - Single-node Kafka-compatible message broker
   - Topic: `ais_data` (auto-created via init container)
   - Retention: 7 days (configurable)
   - Acts as buffer between producer and consumer

3. **ClickHouse Kafka Engine:**
   - `position_reports_kafka` table continuously polls Kafka topic
   - `position_reports_mv` materialized view processes each message
   - Near real-time ingestion (sub-second latency)
   - Automatic deduplication via `ReplacingMergeTree`

### Data Warehouse

**Technology:** ClickHouse (OLAP database)

**Table Design:**

```sql
position_reports
├── ENGINE: ReplacingMergeTree(consumed_at)
├── PARTITION BY: toYYYYMM(produced_at)
├── ORDER BY: (user_id, produced_at)
└── TTL: produced_at + 1 YEAR
```

**Optimization Strategies:**

1. **Partitioning:**
   - Monthly partitions by `produced_at` timestamp
   - Enables efficient data pruning for time-range queries
   - Auto-deletea old data on TTL
   - Supports parallel query execution across partitions

2. **Clustering:**
   - Ordered by `(user_id, produced_at)`
   - Co-locates data for the same vessel (optimizes vessel tracking queries)
   - Secondary sort by time enables fast range scans

3. **Engine Selection:**
   - `ReplacingMergeTree` handles late-arriving duplicates
   - Deduplication happens during merges (eventually consistent)
   - Latest version (by `consumed_at`) is kept

4. **Compression:**
   - ClickHouse default codecs (LZ4) achieve ~10x compression
   - Columnar storage minimizes I/O for analytical queries

### Transformations

**Technology:** dbt (data build tool) with ClickHouse adapter

**Transformation Layers:**

1. **Staging Layer** (`models/staging/`):
   - `stg_position_reports`: Cleaned and filtered source data

2. **Marts Layer** (`models/marts/`):
   
   **a) `vessel_activity`** (incremental model):
   - Hourly aggregations per vessel (MMSI)
   - Updated incrementally last 2 hours on each run (efficient)
   
   **b) `vessel_last_position`** (incremental model):
   - Latest known position for each vessel
   - Updated incrementally last 2 hours on each run (efficient)

### Orchestration

**Technology:** Apache Airflow (LocalExecutor)

**Workflow:** Airflow DAG runs `dbt run` every 15 minuter to refresh models.

- **DAG:** `ais_dbt_transformations`
- **Tasks:**
  1. `dbt_run`: Executes `dbt run` command
  2. Refreshes all incremental models
  3. Logs and error handling

**Infrastructure:**
- Runs in Docker container
- PostgreSQL backend for metadata storage
- Mounted volumes: DAGs folder + dbt project
- Web UI at `http://localhost:8080`

### Visualization

**Technology:** Grafana

**Data Source:** ClickHouse (direct SQL queries)

**Dashboard panels:**
   - Vessel Map (Geomap)
   - Vessel Status (Pie chart)

---

## Project Structure

```
.
├── .env.example                    # Environment variables template
├── docker-compose.yml              # Infrastructure as code (all services)
├── Makefile                        # Automation commands
├── QUICKSTART.md                   # Step-by-step setup guide
├── README.md                       # This file
│
├── streaming/                      # Data ingestion
│   ├── producer.py                 # WebSocket → Kafka producer
│   ├── models.py                   # Python dataclasses
│   └── requirements.txt            # Python dependencies
│
├── clickhouse/
│   └── initdb/
│       └── 01_init_tables.sql      # ClickHouse schema (tables, Kafka engine)
│
├── ais_transformations/            # dbt project
│   ├── models/
│   │   ├── sources.yml             # Source definitions
│   │   ├── staging/
│   │   │   └── stg_position_reports.sql
│   │   └── marts/
│   │       ├── vessel_activity.sql      # Hourly aggregations
│   │       └── vessel_last_position.sql # Latest positions
│   ├── dbt_project.yml             # dbt configuration
│   └── profiles.yml                # Database connection profiles
│
├── airflow/
│   ├── Dockerfile                  # Airflow image with dbt
│   ├── entrypoint.sh               # Init script (DB setup, admin user)
│   └── dags/
│       └── dbt_transformations.py  # Airflow DAG
│
└── grafana/
    └── provisioning/
        ├── datasources/            # ClickHouse connection
        └── dashboards/
            └── ais_data_analysis.json  # Dashboard JSON
```

---

## Reproducibility

Full setup instructions available in **[QUICKSTART.md](QUICKSTART.md)**

---

## License

Built for the [DataTalksClub Data Engineering Zoomcamp](https://github.com/DataTalksClub/data-engineering-zoomcamp) final project.

---

## Acknowledgments

- **DataTalksClub** for organizing the Data Engineering Zoomcamp
- **AISStream.io** for providing free real-time AIS data access
- Open-source community for amazing tools (ClickHouse, Airflow, dbt, Grafana)
