#!/usr/bin/env bash
#
# The sole responsibility of this script is to auto-generate README.md file.
# Run this script before any commit
#
echo '```' > README.md
./pvpn.sh -h | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> README.md
echo '```' >> README.md
