#!/usr/bin/env ruby

# RDFS - Ruby Distributed File System
# Copyright (C) 2018 Sourcerer, All Rights Reserved
# Written by Robert W. Oliver II - <robert@cidergrove.com>
#
# -- BASIC OVERVIEW --
#
# RDFS monitors for changes within a folder. Once these are detected,
# the files are SHA256 hashed and that hash, along with last-modified
# time is stored in an SQLite3 database. Upon changes, these hashes 
# are updated.
#
# Other machines running RDFS can connect to one another and receive
# these updates, therefore keeping multiple directories across different
# machines in sync.
#
# Since the SHA256 hash is calculated, the system avoids saving the same
# block of data twice. This provides a basic data de-duplication scheme.
#
# While RDFS is functional, it is not an ideal construction of a high
# performance, production-ready distrubted file system. Its primary 
# focus is to demonstrate the concepts involved in such system and
# serve as a teaching tool for these techniques.
#
# -- LICENSE --
# 
# This software is licensed under the GPLv3 or later.
# 

# To install requirements on a Debian based system, run:
# apt install ruby-sqlite3 ruby-daemons

require 'digest'
require 'sqlite3'
require 'find'
require 'logger'
require 'webrick'
require 'uri'
require 'net/http'

require_relative 'lib/updater'
require_relative 'lib/transmitter'
require_relative 'lib/server'

module RDFS

  # CTRL+C Handler
  trap("SIGINT") do
      puts "\nRDFS Shutdown via CTRL+C."
    exit 130
  end

  # If debug is enabled, output will be quite verbose.
  RDFS_DEBUG = 1

  # Default RDFS path
  RDFS_PATH = Dir.home + "/rdfs"

  # SQLite3 database file
  RDFS_DB_FILE = Dir.home + "/.rdfs.sqlite3"

  # SQLite3 schema
  RDFS_SCHEMA_FILES = "
    CREATE TABLE files (
      sha256 VARCHAR(64),
      name VARCHAR(255),
      last_modified INT,
      updated BOOLEAN);"
  RDFS_SCHEMA_NODES = "
    CREATE TABLE nodes (
      ip VARCHAR(15));"

  # RDFS path update frequency (in seconds)
  RDFS_UPDATE_FREQ = 15

  # RDFS transmit frequency (in seconds)
  RDFS_TRANSMIT_FREQ = 5

  # RDFS listen port
  RDFS_PORT = 47656

  # Setup logging
  logger = Logger.new(STDOUT)
  if RDFS_DEBUG
    logger.level == Logger::DEBUG
  else
    logger.level == Logger::WARN
  end

  # Output startup message
  puts "RDFS - Ruby Distributed File System\n"\
    "Copyright (C) 2018 Sourcerer, All Rights Reserved.\n"\
    "Written by Robert W. Oliver II. Licensed under the GPLv3.\n\n"

  # If the database doesn't exist, create it.
  unless File.exists?(RDFS_DB_FILE)
    db = SQLite3::Database.new RDFS_DB_FILE
    db.execute RDFS_SCHEMA_FILES
    db.execute RDFS_SCHEMA_NODES
    db.close
    logger.info("RDFS database was not found, so it was created.")
  end

  # Does file storage area exist?  If not, create it.
  unless Dir.exists?(RDFS_PATH)
    Dir.mkdir(RDFS_PATH)
    logger.info("RDFS directory " + RDFS_PATH + " not found, so it was created.")
  end

  # Open the database
  RDFS_DB = SQLite3::Database.open RDFS_DB_FILE

  # Start the server
  logger.debug("Starting RDFS Server.")
  Thread.new do
  @server = Server.new
  end
  sleep 1

  # Start the updater
  logger.debug("Starting RDFS Updater.")
  Thread.new do
    @updater = Updater.new(RDFS_UPDATE_FREQ)
  end
  sleep 1

  # Start the transmitter
  logger.debug("Starting RDFS Transmitter.")
  @transmitter = Transmitter.new(RDFS_TRANSMIT_FREQ)

  puts "RDFS Shutdown."
 
end

