import json
import random
import time
from datetime import datetime

from kafka import KafkaProducer


def create_sensor_data():
    speed = round(random.uniform(0,120),2)
    rpm = int(speed * random.uniform(20,40))
    engine_temp = round(70 + speed * 0.15 + random.uniform(-3,5),2)
    brake = random.choice([True, False])
    steering_angle = round(random.uniform(-30,30),2)
    return {
        "vehicle_id": f"car-{random.randint(1,10):03d}",
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
            time.sleep(1)

    except KeyboardInterrupt:
        print("\nProducer stopped by user.")

    finally:
        producer.flush()
        producer.close()


if __name__ == "__main__":
    main()