# vehicle-streaming-anomaly-detection

## Overview
이 프로젝트는 차량 센서 이벤트를 Kafka로 스트리밍하고, Flink SQL로 이상 주행 패턴을 분류한 뒤, 결과를 PostgreSQL에 적재하는 예제입니다.

최종 데이터 흐름은 아래와 같습니다.

`producer.py -> Kafka -> Flink SQL -> PostgreSQL`

`consumer.py`는 Kafka 원본 메시지 확인용이며, 실제 이상 분류와 적재는 Flink SQL이 담당합니다.

## Architecture
- Producer: 랜덤 차량 센서 데이터 생성 및 Kafka 전송
- Kafka: `vehicle-sensor-data` 토픽에 이벤트 저장
- Flink SQL: Kafka source를 읽고 `CASE` 조건으로 이상 유형 분류
- PostgreSQL: `anomaly_data` 테이블에 결과 적재

## Repository Structure
- `producer/producer.py`: 랜덤 센서 데이터를 계속 생성해서 Kafka로 전송
- `flink/consumer.py`: Kafka 원본 메시지 확인용 consumer
- `flink/anomaly.sql`: Kafka source, JDBC sink, 이상 분류 SQL 정의
- `flink/src/main/java/com/example/vehicle/VehicleAnomalyJob.java`: `anomaly.sql`을 읽어서 실행하는 Flink application entrypoint
- `flink/pom.xml`: Flink application jar 빌드 설정
- `flink/job.py`: Dockerized Maven 빌드 + Docker Compose 기동 스크립트
- `postgres/init.sql`: PostgreSQL 초기 테이블 생성
- `docker-compose.yml`: Kafka, Zookeeper, Flink, PostgreSQL 실행 정의

## Detection Rules
현재 SQL 분류 규칙은 아래와 같습니다.

- `engine_temp > 90` -> `HIGH_ENGINE_TEMP`
- `rpm > 4500` -> `HIGH_RPM`
- `speed > 100 AND brake = TRUE` -> `HIGH_SPEED_WITH_BRAKE`
- `ABS(steering_angle) > 25` -> `SHARP_STEERING`
- 나머지 -> `NORMAL`

실제 규칙은 [`flink/anomaly.sql`](flink/anomaly.sql) 안의 `CASE` 문으로 관리됩니다.

## How To Run
### Quick Checklist
처음부터 빠르게 확인하려면 아래 4개만 보면 됩니다.

1. `python3 flink/job.py`
2. `.venv/bin/python producer/producer.py`
3. `docker exec jobmanager /opt/flink/bin/flink list`
4. `docker exec postgres psql -U flinkuser -d vehicle_db -c "SELECT * FROM anomaly_data ORDER BY timestamp DESC LIMIT 5;"`

정상이라면:
- Flink job이 `RUNNING`
- PostgreSQL `anomaly_data`에 row가 계속 증가

### 1. Flink SQL pipeline 기동
아래 명령이 Maven 빌드와 Docker Compose 기동을 한 번에 수행합니다.

```bash
python3 flink/job.py
```

이 스크립트는 아래 순서로 동작합니다.

1. Dockerized Maven으로 Flink application jar 빌드
2. Zookeeper, PostgreSQL, Kafka 기동
3. Kafka가 healthy 상태가 될 때까지 대기
4. Flink application mode로 SQL job 실행

### 2. Producer 실행
랜덤 차량 센서 데이터를 계속 Kafka로 보냅니다.

```bash
.venv/bin/python producer/producer.py
```

### 3. Kafka 원본 확인
Kafka에 실제로 메시지가 들어오는지 보고 싶으면 consumer를 실행합니다.

```bash
.venv/bin/python flink/consumer.py
```

### 4. PostgreSQL 적재 확인

```bash
docker exec postgres psql -U flinkuser -d vehicle_db -c "SELECT * FROM anomaly_data ORDER BY timestamp DESC LIMIT 5;"
```

### 5. Flink job 상태 확인

```bash
docker exec jobmanager /opt/flink/bin/flink list
```

정상 상태라면 아래와 비슷한 running job이 보여야 합니다.

```text
insert-into_default_catalog.default_database.anomaly_sink (RUNNING)
```

## Verified Result
아래 항목은 실제로 검증했습니다.

- `python3 flink/job.py` 실행 성공
- Flink job running 상태 확인
- `producer.py`로 랜덤 데이터 전송 확인
- Flink SQL이 Kafka source를 읽고 PostgreSQL로 적재 확인
- PostgreSQL에서 `HIGH_SPEED_WITH_BRAKE`, `NORMAL` 등 분류 결과 확인

예시 조회 결과:

```text
 vehicle_id |    anomaly_reason
------------+-----------------------
 car-002    | NORMAL
 car-004    | HIGH_SPEED_WITH_BRAKE
 car-006    | NORMAL
 car-007    | NORMAL
 car-004    | NORMAL
```

## Why It Failed Before
이번에 제일 많이 막혔던 지점은 아래였습니다.

### 1. JDBC connector 경로가 꼬여 있었음
- Flink SQL이 JDBC sink를 쓰려면 `jdbc` connector factory를 정상적으로 읽어야 하는데, 초기 상태에서는 `flink/lib` 쪽 JDBC jar가 올바른 실행용 jar가 아니었습니다.
- 그래서 SQL 실행 시 `Could not find any factory for identifier 'jdbc'` 오류가 발생했습니다.

### 2. SQL은 있었지만 실행 경로가 안정적이지 않았음
- 처음에는 `anomaly.sql`이 있어도, 실제로 이 SQL을 Flink 클러스터에 안정적으로 제출하는 엔트리가 없었습니다.
- `flink/job.py`가 비어 있어서 실행 절차가 수동에 가까웠고, 환경이 조금만 흔들려도 재현이 어려웠습니다.

### 3. Kafka 재기동 타이밍 이슈
- Kafka 컨테이너를 재생성할 때 Zookeeper에 이전 broker 정보가 잠깐 남아 `NodeExistsException`이 발생했습니다.
- 그래서 compose 첫 기동이 흔들렸고, 뒤이어 Flink 잡 제출도 실패하는 경우가 있었습니다.

### 4. SQL client 기반 제출이 불안정했음
- `sql-client`로 직접 session cluster에 붙이는 경로는 connector/classpath/timing 영향을 크게 받았습니다.
- 지금은 SQL 내용은 그대로 유지하되, Flink application이 `anomaly.sql`을 직접 읽어 실행하도록 바꿔 제출 경로를 고정했습니다.

## What Was Changed
- `anomaly.sql`의 sink를 `print`에서 JDBC sink로 변경
- PostgreSQL 초기 테이블 생성 SQL 추가
- Flink application entrypoint 추가
- Docker Compose를 application mode 중심으로 재정리
- `flink/job.py`에 빌드 및 기동 자동화 추가
- Kafka health 대기 후 Flink를 띄우도록 실행 순서 보강

## Notes
- `producer.py`는 랜덤 데이터를 무한히 전송합니다. 중단하려면 `Ctrl+C`를 사용하면 됩니다.
- `consumer.py`는 Kafka 확인용이므로, 없어도 Flink SQL 적재에는 영향 없습니다.
- 예전 `sql-client` 컨테이너가 orphan 경고를 낼 수 있지만 현재 실행 경로에는 사용되지 않습니다.
