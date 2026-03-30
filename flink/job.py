import subprocess
import sys
import time
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]


def run_command(command: list[str]) -> int:
    return subprocess.run(command, cwd=ROOT_DIR).returncode


def wait_for_kafka(timeout_seconds: int = 60) -> bool:
    deadline = time.time() + timeout_seconds
    inspect_cmd = [
        "docker",
        "inspect",
        "-f",
        "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}",
        "kafka",
    ]
    while time.time() < deadline:
        result = subprocess.run(
            inspect_cmd,
            cwd=ROOT_DIR,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip() == "healthy":
            return True
        time.sleep(2)
    return False


def run() -> int:
    build_dir = ROOT_DIR / "build"
    build_dir.mkdir(exist_ok=True)

    build_cmd = [
        "docker",
        "run",
        "--rm",
        "-v",
        f"{ROOT_DIR}:/workspace",
        "-w",
        "/workspace/flink",
        "maven:3.9.9-eclipse-temurin-11",
        "mvn",
        "-q",
        "clean",
        "package",
    ]
    if run_command(build_cmd) != 0:
        return 1

    jar_path = ROOT_DIR / "flink" / "target" / "vehicle-anomaly-job.jar"
    target_path = build_dir / "vehicle-anomaly-job.jar"
    target_path.write_bytes(jar_path.read_bytes())

    infra_cmd = [
        "docker",
        "compose",
        "up",
        "-d",
        "--force-recreate",
        "zookeeper",
        "postgres",
        "kafka",
    ]
    run_command(infra_cmd)

    if not wait_for_kafka():
        return 1

    flink_cmd = [
        "docker",
        "compose",
        "up",
        "-d",
        "--force-recreate",
        "jobmanager",
        "taskmanager",
    ]
    return run_command(flink_cmd)


if __name__ == "__main__":
    sys.exit(run())
