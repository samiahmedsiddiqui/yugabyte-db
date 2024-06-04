---
title: YB Voyager Migration Assessment
linkTitle: Assess migration
headcontent: Steps to create a migration assessment report
description: Steps to create a migration assessment report to ensure successful migration using YugabyteDB Voyager.
menu:
  preview_yugabyte-voyager:
    identifier: assess-migration
    parent: migration-types
    weight: 101
techPreview: /preview/releases/versioning/#feature-maturity
type: docs
---

The Voyager Migration Assessment feature is specifically designed to optimize the database migration process from various source databases, currently supporting PostgreSQL to YugabyteDB. Voyager conducts a detailed analysis of the source database by capturing essential metadata and metrics. It generates a comprehensive assessment report that recommends effective migration strategies, and provides key insights on ideal cluster configurations for optimal performance with YugabyteDB.

## Overview

Voyager collects various metadata or metrics from the source database, such as table columns metadata, sizes of tables/indexes, read/write IOPS for tables/indexes, and so on. With this data, an assessment report is prepared which covers the following key details:

- **Database compatibility**: Assesses the compatibility of the source database with YugabyteDB, identifying unsupported features and data types.

- **Cluster size evaluation**: Provides an estimation of the resource requirements for the target environment, helping in the planning and scaling of infrastructure needs. The sizing logic depends on various factors such as the size and number of tables in the source database, as well as the throughput requirements (read/write IOPS).

- **Schema evaluation**: Reviews the database schema, to suggest effective sharding strategies for tables and indexes.

- **Performance metrics**: Analyzes performance metrics to understand workload characteristics, and provides recommendations for optimization in YugabyteDB.

- **Migration time estimation**: Offers a calculated estimate of the time needed to import data into YugabyteDB after export from the source database, helping with better migration planning. These estimates are calculated based on various experiments during data import to YugabyteDB.

{{< warning title="Caveats" >}}
Recommendations are based on experiments done on [RF3](../../../architecture/docdb-replication/replication/#replication-factor) setup on instance types with 4GiB memory/core against YugabyteDB v2024.1.
{{< /warning >}}

Note that for cases where it is not possible to provide database access to the client machine running voyager, you can gather the metadata from the source database using plain bash/psql scripts by voyager, and then use voyager to analyze the metadata directly.

### Sample Migration Assessment Report

A sample Migration Assessment Report is as follows:

![Migration report](/images/migrate/assess-migration.jpg)

## Generate a Migration Assessment Report

1. [Install yb-voyager](../../install-yb-voyager/).
1. Prepare the source database.

    1. Create a new user, `ybvoyager` as follows:

        ```sql
        CREATE USER ybvoyager PASSWORD 'password';
        ```

    1. Grant necessary permissions to the `ybvoyager` user.

        ```sql
        /* Switch to the database that you want to migrate.*/
        \c <database_name>

        /* Grant the USAGE permission to the ybvoyager user on all schemas of the database.*/

        SELECT 'GRANT USAGE ON SCHEMA ' || schema_name || ' TO ybvoyager;' FROM information_schema.schemata; \gexec

        /* The above SELECT statement generates a list of GRANT USAGE statements which are then executed by psql because of the \gexec switch. The \gexec switch works for PostgreSQL v9.6 and later. For older versions, you'll have to manually execute the GRANT USAGE ON SCHEMA schema_name TO ybvoyager statement, for each schema in the source PostgreSQL database. */

        /* Grant SELECT permission on all the tables. */

        SELECT 'GRANT SELECT ON ALL TABLES IN SCHEMA ' || schema_name || ' TO ybvoyager;' FROM information_schema.schemata; \gexec
        ```

1. Assess migration - Voyager supports two primary modes for conducting migration assessments, depending on your access to the source database as follows:

    1. **With source database connectivity**: This mode requires direct connectivity to the source database from the client machine where voyager is installed. You initiate the assessment by executing the `assess-migration` command of `yb-voyager`. This command facilitates a live analysis by interacting directly with the source database, to gather metadata required for assessment. A sample command is as follows:

        ```sh
        yb-voyager assess-migration --source-db-type postgresql \
        --source-db-host hostname --source-db-user ybvoyager \
        --source-db-password password --source-db-name dbname \
        --source-db-schema schema1,schema2 --export-dir /path/to/export/dir
        ```

    1. **Without source database connectivity**: In situations where direct access to the source database is restricted, there is an alternative approach. Voyager includes packages with scripts present at `/etc/yb-voyager/gather-assessment-metadata/postgresql`. You can perform the following steps with these scripts.

        1. Copy the scripts to a machine which has access to the source database.
        1. Run the `yb-voyager-pg-gather-assessment-metadata.sh` script by providing the source connection string, the schema names, path to a directory where metadata will be saved, and an optional argument of an interval to capture the IOPS metadata of the source (in seconds with a default value of 120). For example,

            ```sh
            /path/to/yb-voyager-pg-gather-assessment-metadata.sh 'postgresql://ybvoyager@host:port/dbname' 'schema1|schema2' '/path/to/assessment_metadata_dir' '60'
            ```

        1. Copy the metadata directory to the client machine on which voyager is installed, and run the `assess-migration` command by specifying the path to the metadata directory as follows:

            ```sh
            yb-voyager assess-migration --source-db-type postgresql \
                 --assessment-metadata-dir /path/to/assessment_metadata_dir --export-dir /path/to/export/dir
            ```

        The output of both the methods is a migration assessment report, and its path is printed on the console.

      {{< warning title="Important" >}}
For the most accurate migration assessment, the source database must be actively handling its typical workloads at the time the metadata is gathered. This ensures that the recommendations for sharding strategies and cluster sizing are well-aligned with the database's real-world performance and operational needs.
      {{< /warning >}}

1. Create a target YugabyteDB cluster as follows:

    1. Create a cluster based on the sizing recommendations in the assessment report.
    1. Create a database with colocation set to TRUE.

        ```sql
        CREATE DATABASE <TARGET_DB_NAME> with COLOCATION=TRUE;
        ```

1. Proceed with migration with one of the migration workflows:

    - [Offline migration](../../migrate/migrate-steps/)
    - [Live migration](../../migrate/live-migrate/)
    - [Live migration with fall-forward](../../migrate/live-fall-forward/)
    - [Live migration with fall-back](../../migrate/live-fall-back/)

## Learn more

- [Assess migration CLI](../../reference/assess-migration/)