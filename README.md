<img src="/SeaVee/Assets.xcassets/AppIcon.appiconset/SeaVeeAsset.png" width="200px">

# SeaVee
An app that provides crew members on cruise ships the ability to track their itineraries and port destinations over the period of their work contract

## Main Features
- Imports cruises using REST API (Cruisemapper Cruises Scraper via Apify) and geocodes itinerary locations (Google Places API)
- Lists imported cruises with summary stats on number of ships, cruises, and unique ports and countries
- Detailed page view of individual cruises with itinerary info
- MapKit integration displaying visited port locations with animated route
- Data saved locally on device with SwiftData

## Project Structure
- `Cruise.swift`: Data model for `Cruise` including (as the associated itinerary) an array of `CruiseStop` which stores geographic coordinates of the stop
- `CruiseDetailView.swift`: Detailed view of a single cruise which includes all associated data including the itinerary route. This view includes the MapKit integration displaying an animated route based on coordinates of the cruise stops.
- `CruiseInputView.swift`: Input view where users specify their contract dates and which cruise ship they are working on. The import button calls the cruise API to fetch the data, then it is parsed and run through the Google Places API to geocode the string locations of cruise stops before being saved to SwiftData.
- `CruiseListView.swift`: List view to see all cruises that have been imported with the app including summary tiles of number of cruises, number  of ships, number of unique ports visited, and number of unique countries visited.
- `CruiseScraper.swift`: Structs that define the responses from the Cruisemapper Cruises Scraper API which includes parsing an unknown length of cruise stops.
- `GooglePlaces.swift`: Structs that define the responses from the Google Places API.
- `Networking.swift`: Networking service for making network calls to the APIs and handling responses and errors.
- `SeaVeeApp.swift`: Main entry point for the app where the model container is set and where API tokens are set using environment variables.
