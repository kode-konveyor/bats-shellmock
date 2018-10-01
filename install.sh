#!/usr/bin/env bash
#--------------------------------------------------------------------------------
# SPDX-Copyright: Copyright (c) Capital One Services, LLC
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#---------------------------------------------------------------------------------
# File: install.sh
# Purpose:
#     This script copies shellmock to the appropriate installation root.
#---------------------------------------------------------------------------------

set -e


PREFIX="$1"
if [ -z "$1" ]; then
  { echo "usage: $0 <prefix>"
    echo "  e.g. $0 /usr/local"
  } >&2
  exit 1
fi

mkdir -p "$PREFIX"/bin
cp -R bin/* "$PREFIX"/bin/


echo "Installed bash_shell_mock to $PREFIX/bin/shellmock"