import json
from kafka import KafkaConsumer


def main():
    try:
        consumer = KafkaConsumer(
            "vehicle-sensor-data",
            bootstrap_servers="localhost:29092",
            auto_offset_reset="earliest",
            enable_auto_commit=True,
            group_id="vehicle-consumer-group",
            value_deserializer=lambda x: json.loads(x.decode("utf-8"))
        )

        print("Waiting for sensor data from Kafka...\n")

        for message in consumer:
            data = message.value

            print(f"[Topic: {message.topic} | Partition: {message.partition} | Offset: {message.offset}]")
            print(
                f"vehicle_id={data.get('vehicle_id')}, "
                f"timestamp={data.get('timestamp')}, "
                f"speed={data.get('speed')}, "
                f"rpm={data.get('rpm')}, "
                f"engine_temp={data.get('engine_temp')}, "
                f"brake={data.get('brake')}, "
                f"steering_angle={data.get('steering_angle')}"
            )
            print("-" * 60)

    except KeyboardInterrupt:
        print("\nConsumer stopped by user.")

    except Exception as e:
        print(f"Error occurred: {e}")

    finally:
        try:
            consumer.close()
        except:
            pass


if __name__ == "__main__":
    main()