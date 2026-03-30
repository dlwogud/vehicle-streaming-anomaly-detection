package com.example.vehicle;

import java.nio.file.Files;
import java.nio.file.Path;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;

public class VehicleAnomalyJob {
    private static final Path SQL_FILE = Path.of("/opt/flink/sql/anomaly.sql");

    public static void main(String[] args) throws Exception {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(
                org.apache.flink.streaming.api.environment.StreamExecutionEnvironment
                        .getExecutionEnvironment(),
                settings);

        String sqlScript = Files.readString(SQL_FILE);
        TableResult lastResult = null;
        for (String statement : sqlScript.split("(?m);\\s*$")) {
            String trimmed = statement.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            lastResult = tableEnv.executeSql(trimmed);
        }

        if (lastResult == null) {
            throw new IllegalStateException("No SQL statements found in " + SQL_FILE);
        }

        lastResult.await();
    }
}
