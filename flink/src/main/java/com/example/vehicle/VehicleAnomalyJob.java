package com.example.vehicle;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.StatementSet;
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
        List<String> insertStatements = new ArrayList<>();

        for (String statement : sqlScript.split("(?m);\\s*$")) {
            String trimmed = statement.trim();
            if (trimmed.isEmpty()) continue;
            if (trimmed.toUpperCase().startsWith("INSERT")) {
                insertStatements.add(trimmed);
            } else {
                tableEnv.executeSql(trimmed);
            }
        }

        if (insertStatements.isEmpty()) {
            throw new IllegalStateException("No INSERT statements found in " + SQL_FILE);
        }

        StatementSet stmtSet = tableEnv.createStatementSet();
        for (String insert : insertStatements) {
            stmtSet.addInsertSql(insert);
        }
        stmtSet.execute().await();
    }
}
