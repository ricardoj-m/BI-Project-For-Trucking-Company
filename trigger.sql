CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE OR REPLACE FUNCTION cleaning()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Try to find the official name by cleaning BOTH the master list and the new input
    -- We remove dots, spaces, and accents to ensure a match
    SELECT driver_name, company_name INTO NEW.driver_name, NEW.company_name
    FROM drivers
    WHERE 
      REGEXP_REPLACE(driver_name, '[^a-zA-Z0-9]', '', 'g')
      ILIKE 
      '%' || REGEXP_REPLACE(unaccent(NEW.driver_name), '[^a-zA-Z0-9]', '', 'g') || '%'
      AND 
      REGEXP_REPLACE(company_name, '[^a-zA-Z0-9]', '', 'g')
      ILIKE 
      '%' || REGEXP_REPLACE(unaccent(NEW.company_name), '[^a-zA-Z0-9]', '', 'g') || '%'
    ORDER BY 
      -- PRIORITY 1: The length is an exact match (highest priority)
      (REGEXP_REPLACE(driver_name, '[^a-zA-Z0-9]', '', 'g') = 
       REGEXP_REPLACE(unaccent(NEW.driver_name), '[^a-zA-Z0-9]', '', 'g')) DESC,
      -- PRIORITY 2: If no exact match, pick the shortest name that fits
      length(driver_name) ASC
    LIMIT 1;

    -- 2. Safety Net: If the search finds nothing, we assign a placeholder

    IF NEW.driver_name IS NULL THEN
        NEW.driver_name := 'Unknown';
        NEW.company_name := 'Unknown';
    END IF;

    IF EXISTS (SELECT 1 FROM loads WHERE ticket_number = NEW.ticket_number) THEN
    RETURN NULL; 
    END IF;

    -- 3. Return the cleaned record to be saved in the table
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clean_names
BEFORE INSERT ON loads
FOR EACH ROW
EXECUTE FUNCTION cleaning();

DROP TRIGGER IF EXISTS clean_names ON loads;
