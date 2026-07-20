import json
import random
import time
from datetime import datetime

from kafka import KafkaProducer


def create_sensor_data():
    # 90% normal driving, 10% anomaly injection across four scenarios
    # Weights: [normal, high_temp, high_rpm, emergency_brake, sharp_steer]
    anomaly_type = random.choices(
        ['normal', 'high_temp', 'high_rpm', 'emergency_brake', 'sharp_steer'],
        weights=[90, 3, 3, 2, 2]
    )[0]

    speed = round(random.uniform(0, 130), 2)

    if anomaly_type == 'high_temp':
        # ECT above 110°C warning threshold (OBD-II PID 0x05)
        engine_temp = round(random.uniform(110, 125), 2)
        rpm = int(random.uniform(2000, 4000))
        brake = random.choices([True, False], weights=[15, 85])[0]
        steering_angle = round(random.uniform(-20, 20), 2)

    elif anomaly_type == 'high_rpm':
        # RPM above 5,500 (85% of typical 6,500 redline, OBD-II PID 0x0C)
        engine_temp = round(random.uniform(90, 105), 2)
        rpm = int(random.uniform(5500, 7000))
        brake = False
        steering_angle = round(random.uniform(-20, 20), 2)

    elif anomaly_type == 'emergency_brake':
        # Hard braking above 80 km/h
        speed = round(random.uniform(80, 130), 2)
        engine_temp = round(random.uniform(88, 105), 2)
        rpm = int(600 + speed * random.uniform(20, 30))
        brake = True
        steering_angle = round(random.uniform(-20, 20), 2)

    elif anomaly_type == 'sharp_steer':
        # Steering angle beyond 45° (genuine sharp steering, not parking)
        engine_temp = round(random.uniform(88, 105), 2)
        rpm = int(600 + speed * random.uniform(20, 30))
        brake = random.choices([True, False], weights=[15, 85])[0]
        steering_angle = round(
            random.choice([-1, 1]) * random.uniform(45, 60), 2
        )

    else:
        # Normal driving: ECT 85-105°C, rpm speed-proportional from idle
        engine_temp = round(70 + speed * 0.15 + random.uniform(8, 18), 2)
        rpm = int(600 + speed * random.uniform(20, 35))
        brake = random.choices([True, False], weights=[15, 85])[0]
        steering_angle = round(random.uniform(-20, 20), 2)

    return {
        "vehicle_id": f"car-{random.randint(1, 10):03d}",
        "timestamp": datetime.utcnow().isoformat(),
        "speed": speed,
        "rpm": rpm,
        "engine_temp": engine_temp,
        "brake": brake,
        "steering_angle": steering_angle
    }


def main():
    producer = KafkaProducer(
        bootstrap_servers="localhost:29092",
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )

    topic_name = "vehicle-sensor-data"
    print(f"Sending sensor data to Kafka topic: {topic_name}")

    try:
        while True:
            data = create_sensor_data()
            producer.send(topic_name, value=data)
            print(f"Sent data: {data}")
            time.sleep(0.2)

    except KeyboardInterrupt:
        print("\nProducer stopped by user.")

    finally:
        producer.flush()
        producer.close()


if __name__ == "__main__":
    main()
