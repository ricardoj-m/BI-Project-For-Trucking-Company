CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,      
    driver_name TEXT NOT NULL UNIQUE,      
    truck_number TEXT, 
    is_active BOOLEAN DEFAULT TRUE,            
    statement_type TEXT CHECK (statement_type IN ('company', 'individual')) DEFAULT 'company'
);

CREATE TABLE rates (
    rate_id SERIAL PRIMARY KEY,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    company_name TEXT, 
    rate_per_ton DECIMAL(10, 2),
    rate_type TEXT CHECK (rate_type IN ('per_ton', 'flat')) DEFAULT 'per_ton',
    apply_fsc BOOLEAN DEFAULT TRUE,
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE fsc_rates (
    id SERIAL PRIMARY KEY,
    fsc_percentage DECIMAL(5, 2) NOT NULL, 
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE dispatch_rates (
    id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,
    fee_percentage DECIMAL(5, 2) NOT NULL DEFAULT 8.00, 
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE loads (
    load_id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    company_name TEXT,
    driver_name TEXT NOT NULL,      
    delivery_date DATE NOT NULL,
    truck_number TEXT NOT NULL,  
    ticket_number TEXT NOT NULL UNIQUE,
    material TEXT,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    tons DECIMAL(10, 2) NOT NULL,
    ticket_image_url TEXT,              
    CONSTRAINT fk_driver FOREIGN KEY (driver_name) REFERENCES drivers(driver_name)
);


CREATE INDEX idx_drivers_name_clean ON drivers(driver_name);
CREATE INDEX idx_loads_driver_clean ON loads(driver_name);


CREATE INDEX idx_rate_lookup ON rates(pick_up, drop_off, start_date, end_date);
CREATE INDEX idx_fsc_date ON fsc_rates(start_date, end_date);
CREATE INDEX idx_dispatch_date ON dispatch_rates(company_name, start_date, end_date);
CREATE INDEX idx_loads_date ON loads(delivery_date);




