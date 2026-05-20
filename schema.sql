/**
 * Database Schema: Fleet Logistics & Billing Pipeline
 * Description: Defines the core data models, relational constraints, operational structures, 
 * and lookup registries required to track loads, calculate variable pricing, 
 * and automate statements.
 */

-- ==========================================
-- 1. MASTER REGISTRIES & DATA DICTIONARIES
-- ==========================================

/**
 * Table: drivers
 * Description: Stores the master profile registry for all operational subcontractors and drivers.
 * Business Logic: Tracks organizational alignment and statement routing types (fleet vs. independent payout).
 */
CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,      
    driver_name TEXT NOT NULL UNIQUE,      
    truck_number TEXT, 
    is_active BOOLEAN DEFAULT TRUE,            
    -- Routing rule: Dictates whether earnings consolidate under a parent company or pay directly to an individual
    statement_type TEXT CHECK (statement_type IN ('company', 'individual')) DEFAULT 'company'
);

/**
 * Table: rates
 * Description: Master matrix for client and default route contract pricing.
 * Business Logic: Employs an effective date range matrix to manage seasonal or timeline-driven pricing changes.
 */
CREATE TABLE rates (
    rate_id SERIAL PRIMARY KEY,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    company_name TEXT, -- Optional: NULL indicates a global fallback rate template for the route
    rate_per_ton DECIMAL(10, 2),
    rate_type TEXT CHECK (rate_type IN ('per_ton', 'flat')) DEFAULT 'per_ton',
    apply_fsc BOOLEAN DEFAULT TRUE, -- Flag to determine Fuel Surcharge qualification
    -- Effective timeline validation window
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

/**
 * Table: fsc_rates
 * Description: Fuel Surcharge Index tracking matrix.
 * Business Logic: Frequently updated table to index floating fuel cost parameters across specific operational dates.
 */
CREATE TABLE fsc_rates (
    id SERIAL PRIMARY KEY,
    fsc_percentage DECIMAL(5, 2) NOT NULL, 
    -- Effective timeline validation window
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

/**
 * Table: dispatch_rates
 * Description: Tracks corporate administration fee percentages charged by the dispatcher.
 * Business Logic: Accommodates floating company margins by applying timeline constraints to commission structures.
 */
CREATE TABLE dispatch_rates (
    id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,
    fee_percentage DECIMAL(5, 2) NOT NULL DEFAULT 8.00, 
    -- Effective timeline validation window
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

-- ==========================================
-- 2. TRANSACTIONAL LEDGER
-- ==========================================

/**
 * Table: loads
 * Description: Central core ledger capturing daily operational load summaries reported from the field.
 * Constraints: Enforces strict data-integrity rules via unique tracking ticket numbers and driver validation.
 */
CREATE TABLE loads (
    load_id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    company_name TEXT,
    driver_name TEXT NOT NULL,      
    delivery_date DATE NOT NULL,
    truck_number TEXT NOT NULL,  
    ticket_number TEXT NOT NULL UNIQUE, -- Prevents duplicate billing and multiple entries of the same physical ticket
    material TEXT,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    tons DECIMAL(10, 2) NOT NULL,
    ticket_image_url TEXT,              
    -- Foreign Key Constraint: Restricts loads to drivers verified within the master registry
    CONSTRAINT fk_driver FOREIGN KEY (driver_name) REFERENCES drivers(driver_name)
);

-- ==========================================
-- 3. PERFORMANCE INDEXING STRATEGY
-- ==========================================

/**
 * B-Tree Indexes for Text Normalization Lookups
 * Optimizes relational string operations and eliminates table scans during case-insensitive JOIN pipelines.
 */
CREATE INDEX idx_drivers_name_clean ON drivers(driver_name);
CREATE INDEX idx_loads_driver_clean ON loads(driver_name);

/**
 * Composite & Interval Date Indexes
 * Crucial for rapid execution of time-variant database lookups, preventing high-overhead 
 * sequential scans when matching historical loads against complex timeline matrices.
 */
CREATE INDEX idx_rate_lookup ON rates(pick_up, drop_off, start_date, end_date);
CREATE INDEX idx_fsc_date ON fsc_rates(start_date, end_date);
CREATE INDEX idx_dispatch_date ON dispatch_rates(company_name, start_date, end_date);
CREATE INDEX idx_loads_date ON loads(delivery_date);


