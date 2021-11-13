# bats-shellmock - Common assertions for Bats
#
# To the extent possible under law, the author(s) have dedicated all
# copyright and related and neighboring rights to this software to the
# public domain worldwide. This software is distributed without any
# warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication
# along with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>.
#
# Assertions are functions that perform a test and output relevant
# information on failure to help debugging. They return 1 on failure
# and 0 otherwise.
#
# All output is formatted for readability using the functions of
# `output.bash' and sent to the standard error.

SHELLMOCK_LOAD_SCRIPT=${BASH_SOURCE[0]}
export SHELLMOCK_LOAD_SCRIPT

# shellcheck disable=1090
source "$(dirname "${BASH_SOURCE[0]}")/src/shellmock.bash"