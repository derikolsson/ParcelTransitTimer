PostMasterTransitTime
=====================

## Requirements ##
* [Postmaster.io API key][http://postmaster.io]
* **Origins.txt** - A file containing source ZIPs
* **Destinations.txt** - A file containing destination ZIPs

## What it Does ##
# Origins become columns, destinations become rows
# Systematically runs every origin ZIP to every destination ZIP, subtracts delivery time from current time, converts to days
# Continuously writes to output CSV
