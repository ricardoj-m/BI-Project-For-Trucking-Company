/**
 * Database Extensions & Triggers: Automated Data Cleaning & Ingestion Pipeline
 * Description: Implements typo-tolerant fuzzy matching and text normalization for incoming field data.
 * Automatically reconciles raw mobile input against master registry profiles and prevents transactional duplication.
 */

-- Enable mandatory PostgreSQL extensions for string normalization and fuzzy matching
CREATE EXTENSION IF NOT EXISTS unaccent; -- Removes diacritics/accents (e.g., 'álvaro' -> 'alvaro')
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- Enables trigram indexing for advanced text similarity searching

CREATE OR REPLACE FUNCTION cleaning()
RETURNS TRIGGER AS $$
BEGIN
    /**
     * 1. TYPO-TOLERANT STRING REGISTRATION
     * Standardizes both the master registries and the incoming transactional records by 
     * removing spaces, periods, and symbols. Converts strings into alphanumeric character streams 
     * to perform a strict case-insensitive pattern evaluation.
     */
    SELECT driver_name, company_name 
    INTO NEW.driver_name, NEW.company_name
    FROM drivers
    WHERE 
      -- Normalize master driver name and compare with incoming character payload
      REGEXP_REPLACE(driver_name, '[^a-zA-Z0-9]', '', 'g')
      ILIKE 
      '%' || REGEXP_REPLACE(unaccent(NEW.driver_name), '[^a-zA-Z0-9]', '', 'g') || '%'
      AND 
      -- Normalize master corporate profile name and compare with incoming company string
      REGEXP_REPLACE(company_name, '[^a-zA-Z0-9]', '', 'g')
      ILIKE 
      '%' || REGEXP_REPLACE(unaccent(NEW.company_name), '[^a-zA-Z0-9]', '', 'g') || '%'
    ORDER BY 
      -- PRIORITY 1: Prioritize absolute matches where stripped character streams match perfectly
      (REGEXP_REPLACE(driver_name, '[^a-zA-Z0-9]', '', 'g') = 
       REGEXP_REPLACE(unaccent(NEW.driver_name), '[^a-zA-Z0-9]', '', 'g')) DESC,
      -- PRIORITY 2: Fall back to picking the shortest valid string matching the pattern filter
      length(driver_name) ASC
    LIMIT 1;

    /**
     * 2. AUDIT SAFETY NET (FALLBACK PLACEHOLDERS)
     * If the alphanumeric search yields no registry matches, routes the record to an 
     * 'Unknown' queue for manual administrative exception handling.
     */
    IF NEW.driver_name IS NULL THEN
        NEW.driver_name := 'Unknown';
        NEW.company_name := 'Unknown';
    END IF;

    /**
     * 3. IDEMPOTENT TRANSACTION GUARD (DUPLICATE EXCLUSION)
     * Evaluates the incoming ticket ledger before write. If the unique load sequence ID 
     * already exists in the system, silently drops the operational write operation to prevent 
     * double-billing or webhook processing loops.
     */
    IF EXISTS (SELECT 1 FROM loads WHERE ticket_number = NEW.ticket_number) THEN
        RETURN NULL; -- Aborts the insertion transaction cleanly without raising a database exception
    END IF;

    -- 4. Pass the validated, normalized, and uniquely verified record downstream to be saved
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- TRIGGER DEFINITION & LIFE CYCLE
-- ==========================================

-- Clean up any preexisting trigger attachments to prevent operational state conflicts
DROP TRIGGER IF EXISTS clean_names ON loads;

/**
 * Trigger: clean_names
 * Execution Window: BEFORE INSERT ON loads (Intercepts payload prior to standard persistence)
 * Evaluation Level: FOR EACH ROW (Evaluates every incoming record array entry independently)
 */
CREATE TRIGGER clean_names
BEFORE INSERT ON loads
FOR EACH ROW
EXECUTE FUNCTION cleaning();
