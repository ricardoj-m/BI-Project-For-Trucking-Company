/**
 * Script: statement_generator
 * Description: Google Apps Script Web App Deployment acting as an automation endpoint.
 * Intercepts incoming dashboard administrative HTTP GET requests, extracts query parameters, 
 * pulls matching billing records from the Supabase view, and dynamically populates 
 * a structured spreadsheet statement template.
 */

/**
 * Endpoint: doGet
 * Description: Standard entry point handler for the Apps Script Web App execution lifecycle.
 * @param {Object} e - Event parameter containing HTTP request URL components.
 * @return {TextOutput} Context-aware status notification payload.
 */
function doGet(e) {
  try {
    // 1. URL Parameter Parsing & Fallback Extraction
    var companyName = e.parameter.statement_recipient || "Unknown Company";
    var startDate = e.parameter.start_date;
    var endDate = e.parameter.end_date;

    // 2. Data Procurement Architecture (REST API Target Construction)
    var supabaseUrl = "https://sktspfdyuvnuaiearruf.supabase.co/rest/v1/statements?statement_recipient=eq." + encodeURIComponent(companyName);

    // Apply conditional filters if explicit historical range constraints are supplied
    if (startDate && endDate) {
      supabaseUrl += "&statement_date=gte." + startDate + "&statement_date=lte." + endDate;
    }

    // Direct HTTP Request Dispatch to Secure Cloud Storage Endpoint
    var response = UrlFetchApp.fetch(supabaseUrl, {
      'method': 'get',
      'headers': {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHNwZmR5dXZudWFpZWFycnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTE2MzcsImV4cCI6MjA5MjM2NzYzN30.bWr3KvcayPzedlLhMBqqZB8DnRuruZA_0JDq3khID4Q',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHNwZmR5dXZudWFpZWFycnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTE2MzcsImV4cCI6MjA5MjM2NzYzN30.bWr3KvcayPzedlLhMBqqZB8DnRuruZA_0JDq3khID4Q'
      }
    });

    var rawData = JSON.parse(response.getContentText());

    // 3. Statement Operational Period Resolution
    var dateStrings = rawData.map(function (row) {
      return row.statement_date;
    });

    // Reduce dates to extract boundaries for header text output positioning
    var minDateStr = dateStrings.reduce(function (a, b) { return a < b ? a : b; });
    var maxDateStr = dateStrings.reduce(function (a, b) { return a > b ? a : b; });
    
    // Internal Helper utility to transform ISO date components (YYYY-MM-DD) to localized standard (MM/DD/YYYY)
    function formatToMMDDYYYY(dateStr) {
      var parts = dateStr.split("-"); 
      return parts[1] + "/" + parts[2] + "/" + parts[0]; 
    }
    var periodString = formatToMMDDYYYY(minDateStr) + " to " + formatToMMDDYYYY(maxDateStr);

    // 4. Data Array Mapping & Structural Realignment
    var dataArray = rawData.map(function (row) {
      return [
        row.delivery_date,
        row.ticket_number,
        "ALLCON" + row.truck_number, -- Prepends standard corporate asset prefix
        row.material,
        row.pick_up,
        row.drop_off,
        row.tons,
        row.rate,
        row.active_fsc_rate / 100   -- Normalizes raw integer percentage to fraction index for currency metrics
      ];
    });

    // Sort transactional dataset chronologically (Oldest execution dates to Newest)
    dataArray.sort(function (a, b) {
      var dateA = new Date(a[0]);
      var dateB = new Date(b[0]);
      return dateA - dateB; 
    });

    // 5. Google Sheets Sheet Clone & Target Lifecycle Operations
    var masterTemplate = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("Template");
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var newSheet = masterTemplate.copyTo(ss);
    newSheet.setName(companyName);

    var startRow = 11; // Insertion starting anchor coordinate matching template layout
    var numRows = dataArray.length;

    // Unshift array operation: Pre-appends a continuous running index count integer (1, 2, 3...) to index column
    for (var i = 0; i < numRows; i++) {
      dataArray[i].unshift(i + 1); 
    }

    // Dynamic Layout Execution Engine
    if (numRows > 0) {
      var templateRange = newSheet.getRange(startRow, 1, 1, newSheet.getLastColumn());

      if (numRows > 1) {
        // Expand the active canvas downward while retaining formatting rules and styling
        var insertRowIndex = startRow + 1;
        newSheet.insertRows(insertRowIndex, numRows - 1);

        var targetRange = newSheet.getRange(startRow + 1, 1, numRows - 1, newSheet.getLastColumn());
        templateRange.copyTo(targetRange, SpreadsheetApp.CopyPasteType.PASTE_NORMAL, false);
        // Note: PASTE_NORMAL effectively maps cell formatting configurations down to newly added records
      }
      
      /**
       * Column Segmentation Multi-Array Split:
       * Extracts the FSC Rate column (the last parameter item in the dataset matrix) 
       * to allow spatial separation for internal, self-calculating spreadsheet formulas.
       */
      var fscRateColumn = dataArray.map(function (row) {
        return [row.pop()]; // Pops structural elements out into its own separate 2D array container
      });

      // Commit core structural data blocks to worksheet (Excluding FSC Rate)
      var mainDataWidth = dataArray[0].length;
      newSheet.getRange(startRow, 1, numRows, mainDataWidth).setValues(dataArray);

      // Commit separated FSC Rate array data exactly 1 column down past the core data stream gap
      var fscColumnIndex = mainDataWidth + 2; // +1 to bridge past dataset boundary, +1 to bypass formula spacer column
      newSheet.getRange(startRow, fscColumnIndex, numRows, 1).setValues(fscRateColumn);

      // 6. Coordinate Formulation Calculation Tracking
      var lastDataRow = startRow + numRows - 1; 
      var sumRow = lastDataRow + 2;             // Positions formula row safely two lines beneath the data block array

      var dynamicSumFormula = "=SUM(J" + startRow + ":J" + lastDataRow + ")";
      var dynamicSumFormula2 = "=SUM(L" + startRow + ":L" + lastDataRow + ")";

      // Inject dynamically compiled string formulas back into targeted sum rows (Columns J and L coordinate sets)
      newSheet.getRange(sumRow, 6).setFormula(dynamicSumFormula);
      newSheet.getRange(sumRow, 9).setFormula(dynamicSumFormula2);
    }

    // 7. Header Identification Parameter Binding
    newSheet.getRange(3, 8).setValue(periodString);
    newSheet.getRange(4, 8).setValue(companyName.toUpperCase());

    return ContentService.createTextOutput("Success! Statement created for " + companyName);

  } catch (error) {
    // Graceful exception capture notification loop
    return ContentService.createTextOutput("Error: " + error.message);
  }
}
