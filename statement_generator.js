function doGet(e) {
  try {
    // 1. Get the parameters from the URL
    var companyName = e.parameter.statement_recipient || "Unknown Company";
    var startDate = e.parameter.start_date;
    var endDate = e.parameter.end_date;


    // 2. Fetch data using the dynamic dates
    var supabaseUrl = "https://sktspfdyuvnuaiearruf.supabase.co/rest/v1/statements?statement_recipient=eq." + encodeURIComponent(companyName);

    if (startDate && endDate) {
      supabaseUrl += "&statement_date=gte." + startDate + "&statement_date=lte." + endDate;
    }

    var response = UrlFetchApp.fetch(supabaseUrl, {
      'method': 'get',
      'headers': {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHNwZmR5dXZudWFpZWFycnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTE2MzcsImV4cCI6MjA5MjM2NzYzN30.bWr3KvcayPzedlLhMBqqZB8DnRuruZA_0JDq3khID4Q',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHNwZmR5dXZudWFpZWFycnVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTE2MzcsImV4cCI6MjA5MjM2NzYzN30.bWr3KvcayPzedlLhMBqqZB8DnRuruZA_0JDq3khID4Q'
      }
    });

    var rawData = JSON.parse(response.getContentText());


    var dateStrings = rawData.map(function (row) {
      return row.statement_date;
    });

    var minDateStr = dateStrings.reduce(function (a, b) { return a < b ? a : b; });
    var maxDateStr = dateStrings.reduce(function (a, b) { return a > b ? a : b; });
    function formatToMMDDYYYY(dateStr) {
      var parts = dateStr.split("-"); // Splits into [YYYY, MM, DD]
      return parts[1] + "/" + parts[2] + "/" + parts[0]; // Returns MM/DD/YYYY
    }
    var periodString = formatToMMDDYYYY(minDateStr) + " to " + formatToMMDDYYYY(maxDateStr);

    // Convert to array for the sheet...
    var dataArray = rawData.map(function (row) {
      return [
        row.delivery_date,
        row.ticket_number,
        "ALLCON" + row.truck_number,
        row.material,
        row.pick_up,
        row.drop_off,
        row.tons,
        row.rate,
        row.active_fsc_rate / 100
      ];
    });

    dataArray.sort(function (a, b) {
      var dateA = new Date(a[0]);
      var dateB = new Date(b[0]);
      return dateA - dateB; // Oldest to newest
    });

    // 3. Populate your template as before
    var masterTemplate = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("Template");
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var newSheet = masterTemplate.copyTo(ss);
    newSheet.setName(companyName);

    var startRow = 11;
    var numRows = dataArray.length;

    // 1. Add index column values to the beginning of each row
    for (var i = 0; i < numRows; i++) {
      dataArray[i].unshift(i + 1); // Inserts the row number at the start of the array
    }

    // Check if there is data to write
    if (numRows > 0) {
      var templateRange = newSheet.getRange(startRow, 1, 1, newSheet.getLastColumn());

      if (numRows > 1) {
        // Insert rows and copy template format (including your formulas!)
        var insertRowIndex = startRow + 1;
        newSheet.insertRows(insertRowIndex, numRows - 1);

        var targetRange = newSheet.getRange(startRow + 1, 1, numRows - 1, newSheet.getLastColumn());
        templateRange.copyTo(targetRange, SpreadsheetApp.CopyPasteType.PASTE_NORMAL, false);
        // Note: PASTE_NORMAL ensures formulas copy down to the new rows perfectly
      }
      // Extract just the FSC Rate (the very last element of every row) into its own array
      var fscRateColumn = dataArray.map(function (row) {
        return [row.pop()]; // Removes the last item from the row and returns it as a 2D array element
      });

      // 2. Write the main data (everything EXCEPT the FSC Rate)
      var mainDataWidth = dataArray[0].length;
      newSheet.getRange(startRow, 1, numRows, mainDataWidth).setValues(dataArray);

      // 3. Write the FSC Rate exactly one column after the main data 
      // (Leaving a 1-column gap where your formula lives)
      var fscColumnIndex = mainDataWidth + 2; // +1 to step past main data, +1 to skip the formula column
      newSheet.getRange(startRow, fscColumnIndex, numRows, 1).setValues(fscRateColumn);

      var lastDataRow = startRow + numRows - 1; // The row where data ends
      var sumRow = lastDataRow + 2;             // Your total row (right below the data)

      // Change "B" to whichever column letter contains the column you need to sum up!
      // This builds a string like: "=SUM(B11:B25)"
      var dynamicSumFormula = "=SUM(J" + startRow + ":J" + lastDataRow + ")";
      var dynamicSumFormula2 = "=SUM(L" + startRow + ":L" + lastDataRow + ")";

      // Write the formula directly into your total row (Column B in this example)
      newSheet.getRange(sumRow, 6).setFormula(dynamicSumFormula);
      newSheet.getRange(sumRow, 9).setFormula(dynamicSumFormula2);
    }

    newSheet.getRange(3, 8).setValue(periodString);
    newSheet.getRange(4, 8).setValue(companyName.toUpperCase());

    return ContentService.createTextOutput("Success! Statement created for " + companyName);

  } catch (error) {
    return ContentService.createTextOutput("Error: " + error.message);
  }
}
