# 0.0.6

- data schema changes:
  - title attribute used for field names instead of description
  - printable field names in `print` attribute

- Added: `set_agent_info`
- Added: for development: `rake swagger:diff` to detect upstream schema changes
- Changed: methods now return a wrapped result
- Fixed: key loading now works on ruby 2.5+ (#1)
