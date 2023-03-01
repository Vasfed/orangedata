# Changelog

## 1.0.0

- breaking: drop support for EOL versions of ruby (< 2.7)
- possibly breaking: added vat20 to match current protocol

## 0.1.0

- Deprecated support for EOL ruby versions < 2.6 - gem may continue to work, but will not be tested against
- Switched CI to github actions
- ruby 3.0, 3.1 support

## 0.0.10
- Changed cashless print title per law change

## 0.0.9

- Added: Payment method names in schema
- Added: credentials#certificate_subject
- Added: `Receipt#as_json` and `.from_hash`

## 0.0.8

- Fixed: return `nil` when document is not ready yet

## 0.0.7

- data schema update to 2.23.0 (15.06.2019)
- Added: load credentials from zip file via rubyzip (no dependency, only accept already opened object)
- Added: Credentials#from_hash now accepts `key_pass` argument

## 0.0.6

- data schema changes:
  - title attribute used for field names instead of description
  - printable field names in `print` attribute

- Added: `set_agent_info`
- Added: for development: `rake swagger:diff` to detect upstream schema changes
- Changed: methods now return a wrapped result
- Fixed: key loading now works on ruby 2.5+ (#1)
