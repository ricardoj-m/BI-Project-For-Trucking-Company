/**
 * View: statements
 * Description: Consolidates individual raw logistics load summaries into client/carrier ready statements.
 * Handles typo-tolerant matching, dynamically resolves time-variant pricing rules based on 
 * delivery timelines, evaluates fuel surcharge applicability, and computes final financial balances.
 */

DROP VIEW IF EXISTS statements;
CREATE OR REPLACE VIEW statements AS

WITH rate_priority AS (
    /**
     * CTE: rate_priority
     * Determines the optimal base contract rate for each load record.
     * Evaluates compound joins across pick-up/drop-off pairs and matching valid timelines.
     * Prioritizes client-specific custom rates over generic fallback rates via standard rank evaluation.
     */
    SELECT 
        l.load_id,
        r.rate_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.load_id 
            -- Rank 1 goes to custom client contracts, fallback goes to NULL company templates
            ORDER BY (CASE WHEN r.company_name IS NOT NULL THEN 1 ELSE 2 END) 
        ) as priority_rank
    FROM loads l
    JOIN drivers d ON lower(l.driver_name) = lower(d.driver_name)
    JOIN rates r ON lower(l.pick_up) = lower(r.pick_up)
        AND lower(l.drop_off) = lower(r.drop_off)
        AND (l.company_name = r.company_name OR r.company_name IS NULL)
        -- Enforce time-variant validity constraint
        AND l.delivery_date >= r.start_date 
        AND l.delivery_date <= r.end_date
), 
matched_data AS (
    /**
     * CTE: matched_data
     * Consolidates structured metrics and dynamically maps corresponding pricing indices.
     * Automatically handles operational business exclusions and evaluates tiered dispatcher percentages.
     */
    SELECT 
        l.load_id,
        l.company_name,
        l.driver_name,
        -- Routing logic: Direct payments bypass fleet templates to pay individual operators
        CASE 
            WHEN d.statement_type = 'individual' THEN l.driver_name
            ELSE l.company_name
        END AS statement_recipient,
        l.delivery_date,
        l.statement_date,
        l.ticket_number,
        l.truck_number,
        l.material,
        l.pick_up,
        l.drop_off,
        l.tons,
        -- Standardize raw unit tracking (Flat-fee items return null tonnage multipliers)
        CASE 
            WHEN r.rate_type = 'flat' THEN NULL
            ELSE r.rate_per_ton
        END AS rate,
        -- Base Gross Value: Computes variable tonnage scaling or applies direct flat fees
        CASE 
            WHEN r.rate_type = 'flat' THEN r.rate_per_ton
            ELSE ROUND((l.tons * r.rate_per_ton), 2)
        END AS subtotal,
        -- Cascading Dispatch Fee resolution: Driver-specific overrides take priority over general company agreements
        COALESCE(dr_driver.fee_percentage, dr_company.fee_percentage) AS active_dispatch_rate,
        -- Conditional Fuel Surcharge (FSC) Assessment: Excludes default fleet parent profiles and flags disabled items
        CASE 
            WHEN (l.company_name = 'Allcon Trucking' OR r.apply_fsc = FALSE) THEN 0.00
            ELSE COALESCE(f.fsc_percentage, 0.00)
        END AS active_fsc_rate,
        r.apply_fsc
    FROM loads l
    -- Filter and lock the best matching rate determined in the initial ranking pipeline
    JOIN rate_priority rp ON l.load_id = rp.load_id AND rp.priority_rank = 1
    JOIN rates r ON rp.rate_id = r.rate_id
    JOIN drivers d ON lower(l.driver_name) = lower(d.driver_name)
    -- Contextual Join: Fetches index rate matching historical delivery dates
    LEFT JOIN fsc_rates f ON l.delivery_date >= f.start_date 
        AND l.delivery_date <= f.end_date
    -- Contextual Join: Pinpoints driver-level dispatch agreements valid on delivery
    LEFT JOIN dispatch_rates dr_driver ON l.company_name = dr_driver.company_name
        AND l.driver_name = dr_driver.driver_name
        AND l.delivery_date >= dr_driver.start_date 
        AND l.delivery_date <= dr_driver.end_date
    -- Contextual Join: Fallback to global company-level dispatch structures
    LEFT JOIN dispatch_rates dr_company ON l.company_name = dr_company.company_name
        AND dr_company.driver_name IS NULL
        AND l.delivery_date >= dr_company.start_date 
        AND l.delivery_date <= dr_company.end_date
)
SELECT *,
    -- 1. FSC Amount: Dynamic fuel surcharge injection over calculated base revenue
    CASE 
        WHEN apply_fsc = TRUE THEN 
            ROUND(subtotal * (active_fsc_rate / 100), 2)
        ELSE 0
    END AS fsc_amount,

    -- 2. Dispatch Fee Total: Commission deducted from combining base freight and active fuel splits
    ROUND((subtotal + 
        CASE 
            WHEN apply_fsc = TRUE THEN 
                subtotal * (active_fsc_rate / 100)
            ELSE 0
        END) * (active_dispatch_rate / 100), 2) AS dispatch_fee_total,
    
    -- 3. Final Total: Net payout to carrier (Gross Freight + FSC Payout - Dispatch Administration Fee)
    ROUND(
        subtotal
        + 
        CASE 
            WHEN apply_fsc = TRUE THEN 
                subtotal * (active_fsc_rate / 100)
            ELSE 0
        END
        -
        (subtotal + 
        CASE 
            WHEN apply_fsc = TRUE THEN 
                subtotal * (active_fsc_rate / 100)
            ELSE 0
        END) * (active_dispatch_rate / 100)
    , 2) AS final_total
FROM matched_data;


