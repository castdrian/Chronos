# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## 1.5.0 - 2025-09-09

### Added

- added ability to automatically create and switch to a new edition when tapping a book

## 1.4.1 - 2025-09-08

### Added

- added check for `get-task-allow` entitlement to inform users if they need sideload with a dev certificate

## 1.4.0 - 2025-09-07

### Added

- added long press gesture recognizer to the home tab bar item to open Chronos' menu

## 1.3.0 - 2025-09-07

### Changed

- refactored the progress tracking to read metadata from the filesystem instead of using KVC

## 1.2.1 - 2025-09-07

### Fixed

- Restored lightweight NSObject init hook to capture chapter metadata without ASIN KVC scanning

## 1.2.0 - 2025-09-06

### Changed

- swapped out ASIN retrieval method to read from CoreData instead of using KVC, which now produces accurate results

## 1.1.1 - 2025-09-06

### Fixed

- Logger config was using wrong tweak name

## 1.1.0 - 2025-09-06

### Added

- added hook to INVocabulary to prevent Audible from crashing during launch if the com.apple.developer.siri entitlement is missing on Jailed devices
