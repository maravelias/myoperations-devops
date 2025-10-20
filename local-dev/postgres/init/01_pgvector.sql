-- Initializes pgvector extension for the default database (operations)
-- This runs only on first container init (new data directory)
CREATE EXTENSION IF NOT EXISTS vector;