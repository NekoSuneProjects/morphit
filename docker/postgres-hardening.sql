-- POSTGRES_USER is initially created as a superuser by the official image so the
-- initialization can run. Morphit only needs ownership of its own database, so
-- remove cluster-wide administrative privileges after initialization.
ALTER ROLE morphit_indexer NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
