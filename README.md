# data dictionary


``` python
!duckdb -c "SELECT table_name, count(*) AS num_columns FROM information_schema.columns GROUP BY table_name ORDER BY table_name;" gloss.duckdb
```

    Error: unable to open database "gloss.duckdb": IO Error: Could not set lock on file "gloss.duckdb": Conflicting lock is held in /home/linuxbrew/.linuxbrew/Cellar/duckdb/1.0.0/bin/duckdb (PID 169175). However, you would be able to open this database in read-only mode, e.g. by using the -readonly parameter in the CLI. See also https://duckdb.org/docs/connect/concurrency

``` python
!snakemake --filegraph | dot -T png > dag.png
```

    Building DAG of jobs...

![dag](./dag.png)
