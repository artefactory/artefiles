# data: DuckDB and harlequin

- DuckDB CLI (macOS brew; Linux release download): SQL on files with no
  server. `duckdb` opens a shell; `duckdb -c "select * from 'data.parquet' limit 5"`;
  CSV and JSON work the same (`read_csv('f.csv')`). `duckdb my.db` keeps tables
  in a file.
- harlequin (uv tool, on both OSes, with the Postgres adapter): a SQL client in
  the terminal. `harlequin` opens an in-memory DuckDB, `harlequin my.db` a file,
  `harlequin -a postgres "postgresql://user@host/db"` a Postgres database.
  `F1` shows the keys; `Ctrl+Enter` runs the query.
- `uv tool upgrade harlequin` upgrades it between releases.
- Doctor: checks `duckdb` and `harlequin`.
