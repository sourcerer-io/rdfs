
# Ruby Distributed File System (RDFS)

Copyright (C) 2018 Sourcerer, All Rights Reserved
Written by Robert W. Oliver II - <robert@cidergrove.com>

## OVERVIEW

RDFS monitors for changes within a folder. Once these are detected, the files are SHA256 hashed and that hash, along with last-modified time is stored in an SQLite3 database. Upon changes, these hashes are updated.

Other machines running RDFS can connect to one another and receive these updates, therefore keeping multiple directories across different machines in sync.

Since the SHA256 hash is calculated, the system avoids saving the same block of data twice. This provides a basic data de-duplication scheme.

While RDFS is functional, it is not an ideal construction of a high performance, production-ready distrubted file system. Its primary focus is to demonstrate the concepts involved in such system and serve as a teaching tool for these techniques.

## INSTALL

To install requirements on a Debian based system, run:
apt install ruby-sqlite3 ruby-daemons

## USE

ruby rdfsctl.rb start

## LICENSE

This software is licensed under the GPLv3 or later.

## BUGS

There are several known bugs in this release:

* Adding more than 2 nodes may produce unpredictable results
* Compression for transfer was disabled due to Zlib issues
* If database is out of sync with filesystem, unpredictable results will occur

