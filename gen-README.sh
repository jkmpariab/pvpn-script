#!/usr/bin/env bash
#
# The only responsibility of this script is to auto-generate README.md file
# re-run this script on every commit
#
echo '```' > README.md
./pvpn.sh -h | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> README.md
echo '```' >> README.md
