# Congress Historical Data
Scrape historical data of congressional journals and hearings

## Features
Two R scripts for scraping congressional data:
1. Full texts of congressional journals.
2. Hearings data from Proquest.

## Requirements
1. Download Selenium server and store in the same folder as R script from https://www.selenium.dev/downloads/.
2. If opening a browser using Safari:
    1. Open Preferences > Advanced > check "Show Develop menu in menu bar".
    2. In the menu bar: Develop > Allow Remote Automation.
3. If opening a browser using Chrome: 
    Download chromedriver and save in the same folder as R script from https://chromedriver.chromium.org/.
4. Scraping from Proquest may require two-factor authentication depending on your institution. This may require the following:
    1. Running the code in batches depending on time-out periods.
    2. If using Duo, I recommend setting up automatic pushes to your device (a must if using Safari because users cannot edit the browser window).
