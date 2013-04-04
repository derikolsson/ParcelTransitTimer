ParcelTransitTimer
=====================

## Project Status ##
* Not actively developed
* May include some experimental features
* Includes some incomplete features
* In general, not suitable for active use, but available for forking / continual improvement

## Requirements ##
* [Postmaster.io API key](http://postmaster.io)
* **Origins.txt** - A file containing source ZIPs (one per line)
* **Destinations.txt** - A file containing destination ZIPs (one per line)

## What it Does ##
1. Maps origins columns, destinations to rows
1. Systematically runs every origin ZIP to every destination ZIP, subtracts delivery time from current time, converts to days
1. Continuously writes to output CSV
