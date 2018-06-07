#!/bin/bash
set -e

jq --version >/dev/null || { echo "jq must be installed" >&2; exit 1; }
flow >/dev/null || { echo "flow currently has errors, fix them first" >&2; exit 1; }

pass1_files="$(mktemp)"
pass2_files="$(mktemp)"
tempfile="$(mktemp)"

# `export * from` can cause problems that can't be fixed by removing @flow. If
# A imports B and B has `export * from 'C'`, then removing @flow from C will
# actually cause `A` to generate invalid import errors. Flow decides that
# `export *` from an untyped module exports nothing, but also that the module's
# exports are still known (this appears to be a weakness in flow).
#
# So the overall process looks like this:
# 1. Add @flow to all files that don't contain `export *`.
# 2. Remove @flow from any file that now has a type check error.
# 3. For each file that contains `export *`, one at a time:
#    - Add @flow to the file.
#    - If the project now has any errors, remove @flow from the file.

# Pump all input files into the database (skip those that already have flow)
while read filename; do
  echo "filename is $filename"
  filename="$(realpath "$filename")"
  if ! grep -q "@flow" "$filename"; then
    if grep -q 'export *' "$filename"; then
      echo "$filename" >> $pass2_files
    else
      echo "$filename" >> $pass1_files
    fi
  fi
done

# Add flow to all pass 1 files.
cat "$pass1_files" | while read filename; do
  (echo "// @flow"; cat "$filename") >> "$tempfile"
  mv "$tempfile" "$filename"
done

# Now find all of the errors we just introduced and remove the flow declaration from those files.
flow --json | jq -r .errors[].message[].path | sort -u | while read filename; do
  if grep -q "$filename" "$pass1_files"; then
    sed '1d' "$filename" > "$tempfile"
    mv "$tempfile" "$filename"
  fi
done

if ! flow >/dev/null; then
  echo "Adding @flow introduced errors in files that already had flow; aborting." >&2
  exit 1
fi

# Now add flow to each pass 2 file and check for errors
cat "$pass2_files" | while read filename; do
  (echo "// @flow"; cat "$filename") >> "$tempfile"
  mv "$tempfile" "$filename"
  if ! flow >/dev/null; then
    sed '1d' "$filename" > "$tempfile"
    mv "$tempfile" "$filename"
  fi
done
