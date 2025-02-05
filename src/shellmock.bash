#!/usr/bin/env bash
#shellcheck disable=SC2181
#---------------------------------------------------------------------------------
# File: shellmock.bash
# Purpose:
#    This script provides mocking features to test the various bash scripts.
#    They are made available in your current shell by sourcing this script.
#    i.e.  source shellmock.bash
#---------------------------------------------------------------------------------

#---------------------------------------
# Helper function to do targeted testing
#---------------------------------------
skipIfNot() {
  local doskip
  if [ -n "$TEST_FUNCTION" ]; then
    doskip=$(echo "$TEST_FUNCTION|" | awk 'BEGIN{RS="|"}{ if ($0=="'"$1"'") print "true";}')
    if [ "$doskip" != "true" ]; then
      skip
    fi
  fi
}

#----------------------------------------------------------------------------
# This function creates a single string containing all $*.  In the process
# it checks to see if an arg contains a space and if so then it places
# double quotes around the argument.
#
# Note: Even if single quotes were originally used the string and
# any matching in the ${capture{@]} array will have double quotes around
# the arguments.
#----------------------------------------------------------------------------
shellmock_normalize_args() {
  shellmock_debug "shellmock_normalize_args: before *$**"

  #-----------------------------------------------------------------------
  # Shellcheck warnings have been disable below. I think for good reason.
  # The function is all about not losing knowledge about which strings
  # are quoted in the argument list.  In the future I may revisit this.
  # For now I just know I spent a lot of time getting it to work and
  # don't want to break it now.
  #-----------------------------------------------------------------------
  local re="[[:space:]]+"
  local args=""
  for arg in "${@}"; do
    if [[ $arg =~ $re ]]; then
      shellmock_debug "shellmock_normalize_args: found space: $arg"
      # shellcheck disable=SC2089
      args="$args \"$arg\""
      shellmock_debug "shellmock_normalize_args: args: $args"
    else
      args="$args $arg"
    fi
    shellmock_debug "shellmock_normalize_args: args: $args"
  done
  # shellcheck disable=SC2016
  args=$(echo "$args" | $AWK '{$1=$1;print}')
  shellmock_debug "shellmock_normalize_args: after *$args*"
  echo "$args"

}
#---------------------------------------------------------------------
# The variables are being passed to sed and / are important to sed
# so before we send to sed and write to the detour.properties we will
# use sed to replace any / with \/ then the later sed will succeed.
#---------------------------------------------------------------------
shellmock_escape_special_chars() {
  shellmock_debug "shellmock_escape_special_chars: args: $*"
  $ECHO "$*" | $SED -e 's/\//\\\//g' -e 's/\[/\\\[/g' -e 's/\]/\\\]/g'
}
#---------------------------------------------------------------------
# The variables are being passed to sed and / are important to sed
# so before we send to sed and write to the detour.properties we will
# use sed to replace any / with \/ then the later sed will succeed.
#---------------------------------------------------------------------
shellmock_escape_escapes() {
  shellmock_debug "shellmock_escape_escapes: args: $*"
  $ECHO "$*" | $SED -e 's/\\/\\\\/g'
}
#--------------------------------------------------------------------------------------------------------------------------------------
# This function is used to mock bash scripts.  It maps inputs to outputs and if a given script is
# expecting varying results then they are played back in the order the expects were given.
#
# inputs are assumed to be the function name plus command line arguments.
# outputs are the given string provided.
#
# usage: shellmock.bash  [command] --source [command to source] --exec [command to exec] --match [args to match] --output [output to write]
# --source -- specifies the script to source if the args match
# --exec -- specifies the script to execute if the args match
# --match -- arguments to command that should be used to match the record
# --output -- output that should be written to standard out if the args match
# --type  -- type of match partial or exact
#
# NOTE: --source --exec and --output should be mutually exclusive. We should never use more than one at time in the same expect
#--------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------
# This function puts \ in front of " so that it can be passed to awk
#-------------------------------------------------------------------
shellmock_escape_quotes() {
  POSIXLY_CORRECT=1 $ECHO "$*" | $SED -e 's/"/\\"/g'
}

#------------------------------------
# Use awk to determine the match list
#------------------------------------
mock_capture_match() {
  local MATCH
  MATCH=$(shellmock_escape_quotes "$1")

  local IN_MATCH
  IN_MATCH=$(shellmock_escape_quotes "$2")

  shellmock_debug "mock_capture_match: cmd: *$cmd* MATCH: *$MATCH* IN_MATCH: *$IN_MATCH*"

  #shellcheck disable=SC2016
  local AWK_ARG_SCRIPT='BEGIN{FS="@@"}{if ($5=="E" && ($1 == "'"$MATCH"'")) print; if ($5=="P" && index("'"$MATCH"'",$1)) print; if ($5=="X" && match("'"$MATCH"'", $1)) print}'
  shellmock_debug "mock_capture_match: awk arg matcher script: $AWK_ARG_SCRIPT"

  #shellcheck disable=SC2016
  local AWK_STDIN_SCRIPT='BEGIN{FS="@@"}{if ($6=="E" && ($7 == "'"$IN_MATCH"'")) print; if ($6=="P" && index("'"$IN_MATCH"'",$7)) print; if ($6=="X" && match("'"$IN_MATCH"'", $7)) print}'
  shellmock_debug "mock_capture_match: awk stdin matcher script: $AWK_STDIN_SCRIPT"

  $CAT "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.capture.tmp" | $AWK "$AWK_ARG_SCRIPT" | $AWK "$AWK_STDIN_SCRIPT"
}

#------------------------------------
# Use awk to determine the match list
#------------------------------------
mock_state_match() {
  local MATCH
  MATCH=$(shellmock_escape_quotes "$1")
  local IN_MATCH
  IN_MATCH=$(shellmock_escape_quotes "$2")
  shellmock_debug "mock_state_match: cmd: $cmd MATCH: *$MATCH* IN_MATCH: *$IN_MATCH*"
  local AWK_ARG_SCRIPT
  #shellcheck disable=SC2016
  AWK_ARG_SCRIPT='BEGIN{FS="@@"}{if ($3=="E" && ($1 == "'"$MATCH"'")) print; if ($3=="P" && index("'"$MATCH"'",$1)) print;if ($3=="X" && match("'"$MATCH"'", $1)) print}'
  shellmock_debug "mock_state_match: awk arg match cmd: $AWK_ARG_SCRIPT"

  local AWK_STDIN_SCRIPT
  #shellcheck disable=SC2016
  AWK_STDIN_SCRIPT='BEGIN{FS="@@"}{if ($4=="E" && ($5 == "'"$IN_MATCH"'")) print $2; if ($4=="P" && index("'"$IN_MATCH"'",$5)) print $2;if ($4=="X" && match("'"$IN_MATCH"'", $5)) print $2}'
  shellmock_debug "mock_state_match: awk stdin match cmd: $AWK_STDIN_SCRIPT"

  local rec
  rec=$($CAT "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.state.tmp" | $AWK "$AWK_ARG_SCRIPT" | $AWK "$AWK_STDIN_SCRIPT" | $TAIL -1)
  shellmock_debug "mock_state_match: rec: *$rec*"
  $ECHO "$rec"
}

#------------------------------------------------------------------------
# Create the mock stub and write mock expections and actions to tmp files
#------------------------------------------------------------------------
#shellcheck disable=SC2016,SC2129
shellmock_expect() {
  #---------------------------------------
  # The first arg is the command basename.
  #---------------------------------------
  local cmd
  cmd=$1
  shift

  local FORWARD=""
  local MATCH=""
  local OUTPUT=""
  local STATUS=0
  local MTYPE="E"
  local IN_MTYPE="E"

  #--------------------------------------------------------------
  # read the switches so we know what to do
  # --exec -- forward to another command
  # -m,--match,--match-args -- arg list to the base command for matching
  # -M,--match-stdin -- stdin contents for arg matching
  # --output -- standard out that should be echoed
  # --status -- exit status to return
  # -t,--type,--args-match-type  -- exact or partial of arg list
  # -T,--stdin-match-type -- exact or partial match of stdin
  #--------------------------------------------------------------
  while [[ $# -gt 1 ]]; do
    local key="$1"
    case $key in
    -S | --source)
      local SOURCE="$2"
      shift # past argument
      ;;
    -e | --exec)
      FORWARD="$2"
      shift # past argument
      ;;
    -t | --type | --args-match-type)
      if [ "$2" = "partial" ]; then
        MTYPE="P"
      elif [ "$2" = "exact" ]; then
        MTYPE="E"
      elif [ "$2" = "regex" ]; then
        MTYPE="X"
      else
        shellmock_capture_err "mock_expect type $2 not valid should be exact or partial"
        return 1
      fi
      shift # past argument
      ;;
    -T | --stdin-match-type)
      if [ "$2" = "partial" ]; then
        IN_MTYPE="P"
      elif [ "$2" = "exact" ]; then
        IN_MTYPE="E"
      elif [ "$2" = "regex" ]; then
        IN_MTYPE="X"
      else
        shellmock_capture_err "mock_expect type $2 not valid should be exact or partial"
        return 1
      fi
      shift # past argument
      ;;
    -m | --match | --match-args)
      MATCH="$2"
      shift # past argument
      ;;
    -M | --match-stdin)
      local MATCH_IN="$2"
      shift # past argument
      ;;
    -o | --output)
      #---------------------------------------------------------
      # Preserve any newlines in the string by replacing with %%
      # but also remove the trailing %% that awk puts there.
      #---------------------------------------------------------
      OUTPUT=$($ECHO "$2" | $AWK '$1=$1' ORS='%%' | $SED 's/%%$//g')
      shift # past argument
      ;;
    -s | --status)
      STATUS="$2"
      shift # past argument
      ;;
    *)
      # unknown option
      return 1
      ;;
    esac
    shift # past argument or value
  done

  shellmock_debug "shellmock_expect: FORWARD=$FORWARD"
  shellmock_debug "shellmock_expect: MATCH=$MATCH"
  shellmock_debug "shellmock_expect: OUTPUT=$OUTPUT"
  shellmock_debug "shellmock_expect: STATUS=$STATUS"
  shellmock_debug "shellmock_expect: MTYPE=$MTYPE"
  shellmock_debug "shellmock_expect: MATCH_IN=$MATCH_IN"
  shellmock_debug "shellmock_expect: IN_MTYPE=$IN_MTYPE"

  #-----------------------------------------------------------
  # If the command has not been stubbed then generate the stub
  #-----------------------------------------------------------
  if [ ! -f "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd" ]; then

    $MKDIR -p "${BATS_TEST_DIRNAME}/${TEMP_STUBS}"
    $TOUCH "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "#!/usr/bin/env bash" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO ". \"${SHELLMOCK_LOAD_SCRIPT}\"" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO 'shellmock_debug shellmock_stub: $0-stub: args: "$*"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "if [ -p /dev/stdin ]; then" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "    let cnt=0" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "    while IFS= read line; do" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '          stdin[$cnt]=$line' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '          let cnt=$cnt+1' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "     done" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '     if [ $cnt -gt 0 ]; then stdin[$cnt]=" | "; fi' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO 'else' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '    shellmock_debug shellmock_stub: $0-stub: no stdin' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO "fi" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO 'shellmock_debug shellmock_stub: $0-stub: stdin: "${stdin[@]}"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    if [ -z "$SHELLMOCK_V1_COMPATIBILITY" ]; then
      $ECHO 'shellmock_capture_cmd "${stdin[@]}"'"${cmd}"'-stub "$(shellmock_normalize_args "$@")"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
      $ECHO "shellmock_replay $cmd "'"`shellmock_normalize_args "$@"`" "${stdin[@]}"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    else
      $ECHO 'shellmock_capture_cmd '"${cmd}"'-stub "$*"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
      $ECHO "shellmock_replay $cmd "'"$*"' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    fi
    $ECHO 'status=$?' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO 'if [ $status -ne 0 ]; then' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '    shellmock_capture_err $0 failed ' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO '    exit $status' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $ECHO 'fi' >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
    $CHMOD 755 "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd"
  fi

  #---------------------------------------------------------------
  # There are two record formats one for forwards and one for
  # matching inputs and outputs
  #    forward implies executing an alternative command vs mocking
  #
  #---------------------------------------------------------------
  local MATCH_NORM
  if [ "$MTYPE" != "X" ] && [ -z "$SHELLMOCK_V1_COMPATIBILITY" ]; then
    MATCH_NORM=$(eval shellmock_normalize_args "$MATCH")
  else
    MATCH_NORM=$MATCH
  fi

  # Field definitions for the capture file
  # $1 - arg match criteria
  # $2 - type of expectation (forward, source, or output)
  # $3 - data related to the expectation type: script to forward to, the script to source, or the output to display
  # $4 - status value to return
  # $5 - type of argument matcher
  # $6 - type of stdin matcher
  # $7 - stdin match criteria

  shellmock_debug "shellmock_expect: normalized arg match string *$MATCH* as *$MATCH_NORM*"
  if [ "$FORWARD" != "" ]; then
    $ECHO "$MATCH_NORM@@FORWARD@@$FORWARD@@0@@$MTYPE@@$IN_MTYPE@@$MATCH_IN" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.capture.tmp"
  elif [ "$SOURCE" != "" ]; then
    $ECHO "$MATCH_NORM@@SOURCE@@$SOURCE@@0@@$MTYPE@@$IN_MTYPE@@$MATCH_IN" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.capture.tmp"
  else
    $ECHO "$MATCH_NORM@@OUTPUT@@$OUTPUT@@$STATUS@@$MTYPE@@$IN_MTYPE@@$MATCH_IN" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.capture.tmp"
  fi

  # Field definitions for the state file:
  # $1 - argument match criteria
  # $2 - which occurrence is the active when there are multiple responses to playback
  # $3 - argument match type
  # $4 - stdin match type
  # $5 - stdin match criteria
  $ECHO "$MATCH_NORM@@1@@$MTYPE@@$IN_MTYPE@@$MATCH_IN" >>"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$cmd.playback.state.tmp"
}

#----------------------------------------
# This function is used by the mock stubs
# usage: shellmock_replay [cmd]
#----------------------------------------
shellmock_replay() {
  local cmd="$1"
  local match="$2"
  local in_match="$3"

  shellmock_debug "shellmock_replay: cmd: $cmd match: *$match* in_match: *$in_match*"

  local rec
  typeset -i rec

  local count
  typeset -i count

  #-------------------------------------------------------------------------------------
  # Get the record index.  If there are multiple matches then they are returned in order
  #-------------------------------------------------------------------------------------
  rec=$(mock_state_match "$match" "$in_match")
  if [ "$rec" = "0" ]; then
    shellmock_capture_err "No record match found stdin:*$in_match* cmd:$cmd args:*$match*"
    return 99
  fi

  shellmock_debug "shellmock_replay: matched rec: $rec"
  count=$(mock_capture_match "$match" "$in_match" | $WC -l)
  local entry
  entry=$(mock_capture_match "$match" "$in_match" | $HEAD -"${rec}" | $TAIL -1)

  shellmock_debug "shellmock_replay: count: $count entry: $entry"
  #-------------------------------
  # If no entry is found then fail
  #-------------------------------
  if [ -z "$entry" ]; then
    shellmock_capture_err "No match found for stdin: *$in_match* cmd: *$cmd* - args: *$match*"
    exit 99
  fi
  local action
  local output
  local status
  local mtype
  local in_mtype

  #shellcheck disable=SC2016
  action=$($ECHO "$entry" | $AWK 'BEGIN{FS="@@"}{print $2}')

  #shellcheck disable=SC2016
  output=$($ECHO "$entry" | $AWK 'BEGIN{FS="@@"}{print $3}')

  #shellcheck disable=SC2016
  status=$($ECHO "$entry" | $AWK 'BEGIN{FS="@@"}{print $4}')

  #shellcheck disable=SC2016
  mtype=$($ECHO "$entry" | $AWK 'BEGIN{FS="@@"}{print $5}')

  #shellcheck disable=SC2016
  in_mtype=$($ECHO "$entry" | $AWK 'BEGIN{FS="@@"}{print $6}')

  shellmock_debug "shellmock_replay: action: $action"
  shellmock_debug "shellmock_replay: output: $output"
  shellmock_debug "shellmock_replay: status: $status"
  shellmock_debug "shellmock_replay: mtype: $mtype"
  shellmock_debug "shellmock_replay: in_mtype: $in_mtype"

  #--------------------------------------------------------------------------------------
  # If there are multiple responses for a given match then keep track of a response index
  #--------------------------------------------------------------------------------------
  if [ "$count" -gt 1 ]; then
    shellmock_debug "shelmock_replay: multiple matches: $count"
    $CP "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$1.playback.state.tmp" "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$1.playback.state.bak"
    # This script updates index for the next mock when there is more than one response value.
    #shellcheck disable=SC2016
    $CAT "${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$1.playback.state.bak" | $AWK 'BEGIN{FS="@@"}{ if ((($3=="E" && $1=="'"$match"'")||($3=="P"&& index("'"$match"'",$1))||($3=="X" && match("'"$match"'",$1))) && (($4=="E" && $5=="'"$in_match"'")||($4=="P"&& index("'"$in_match"'",$5))||($4=="X" && match("'"$in_match"'",$5)))) printf("%s@@%d@@%s@@%s@@%s\n",$1,$2+1,$3,$4,$5) ; else printf("%s@@%d@@%s@@%s@@%s\n",$1,$2,$3,$4,$5) }' >"${BATS_TEST_DIRNAME}/${TEMP_STUBS}/$1.playback.state.tmp"
  fi

  #--------------------------------------------------------------
  # If this is a command forwarding request then call the command
  #--------------------------------------------------------------
  if [ "$action" = "SOURCE" ]; then
    shellmock_debug "shellmock_replay: perform: SOURCE *. $output*"
    # shellcheck disable=SC1090
    . "$output"
    return $?

  elif [ "$action" = "FORWARD" ]; then
    local tmpcmd
    $ECHO "$output" | $GREP '{}' >/dev/null

    # SUBSTITION Feature
    # If {} is present that means pass the match pattern into the exec script.
    if [ $? -eq 0 ]; then
      local tmpmatch
      tmpmatch=$(shellmock_escape_special_chars "$match")
      tmpcmd=$($ECHO "$output" | $SED "s/{}/$tmpmatch/g")
    else
      tmpcmd=$output
    fi
    shellmock_debug "shellmock_replay: perform: FORWARD *$tmpcmd*"
    eval "$tmpcmd"
    return $?

  #----------------------------
  # Otherwise return the output
  #----------------------------
  else
    shellmock_debug "shellmock_replay: perform: OUTPUT *$output* STATUS: $status"
    #shellcheck disable=SC2016
    $ECHO "$output" | $AWK 'BEGIN{FS="%%"}{ for (i=1;i<=NF;i++) {print $i}}'
    return "$status"
  fi
}

#-------------------------------
# Records that script was called
#-------------------------------
shellmock_capture_cmd() {
  local cmd
  cmd=$(echo "$@" | awk '{$1=$1};1')
  # trim leading and trailing spaces from the command
  shellmock_debug "shellmock_capture_cmd: captured: *$cmd*"
  $ECHO "${cmd}" >>"${CAPTURE_FILE}"
}

#-------------------------
# Write errors to err file
#-------------------------
shellmock_capture_err() {
  $ECHO "$*" >>"${SHELLMOCK_CAPTURE_ERR}"
}

#----------------------------------------------------------------------
# This utility function captures user output and writes to a debug file
#----------------------------------------------------------------------
shellmock_dump() {
  if [ -n "$TEST_FUNCTION" ]; then
    POSIXLY_CORRECT=1 $ECHO "DUMP-START: stdout" >>"${SHELLMOCK_CAPTURE_DEBUG}"
    #shellcheck disable=SC2154
    for idx in ${!lines[*]}; do
      POSIXLY_CORRECT=1 $ECHO "${lines[$idx]}" >>"${SHELLMOCK_CAPTURE_DEBUG}"
    done
    POSIXLY_CORRECT=1 $ECHO "DUMP-END: stdout" >>"${SHELLMOCK_CAPTURE_DEBUG}"
  fi
}

#----------------------------------------------------------------------
# This utility function captures user output and writes to a debug file
#----------------------------------------------------------------------
shellmock_debug() {
  if [ -n "$TEST_FUNCTION" ]; then
    POSIXLY_CORRECT=1 $ECHO "$@" >>"${SHELLMOCK_CAPTURE_DEBUG}"
  fi
}

#----------------------------------
# Clean up an previous capture file
#----------------------------------
shellmock_clean() {
  $RM -f "${CAPTURE_FILE}"
  $RM -f "${SHELLMOCK_CAPTURE_ERR}"
  $RM -f "${SHELLMOCK_CAPTURE_DEBUG}"
  if [ -d "${BATS_TEST_DIRNAME}/${TEMP_STUBS}" ]; then
    $RM -rf "${BATS_TEST_DIRNAME}/${TEMP_STUBS}"
  fi
}

#---------------------------------------------------
# Read the capture file into an array called capture
#---------------------------------------------------
shellmock_verify() {
  local index=0
  local line
  while read -r line; do
    capture[$index]="$line"
    index=$index+1
  done <"${CAPTURE_FILE}"

  export capture
  return 0
}

#---------------------------------------------------
# Verify number of times called
#---------------------------------------------------
function shellmock_verify_times() {
  [[ "${#capture[*]}" == $1 ]]
}

#---------------------------------------------------
# Verify command of nth time stubs called
#---------------------------------------------------
function shellmock_verify_command() {
  [[ "${capture[$1]}" == "$2" ]]
}

#-------------------------------------------------------------------------------------------------------
# In case users need to mock lower level commands then make sure that shellmock.bash knows the exact location of
# key commands it needs.
#-------------------------------------------------------------------------------------------------------
if [ -z "$ECHO" ]; then
  ECHO=$(command -p -v echo)
  export ECHO
fi
if [ -z "$CP" ]; then
  CP=$(command -p -v cp)
  export CP
fi
if [ -z "$CAT" ]; then
  CAT=$(command -p -v cat)
  export CAT
fi
if [ -z "$RM" ]; then
  RM=$(command -p -v rm)
  export RM
fi
if [ -z "$AWK" ]; then
  AWK=$(command -p -v awk)
  export AWK
fi
if [ -z "$GREP" ]; then
  GREP=$(command -p -v grep)
  export GREP
fi
if [ -z "$MKDIR" ]; then
  MKDIR=$(command -p -v mkdir)
  export MKDIR
fi
if [ -z "$TOUCH" ]; then
  TOUCH=$(command -p -v touch)
  export TOUCH
fi
if [ -z "$CHMOD" ]; then
  CHMOD=$(command -p -v chmod)
  export CHMOD
fi
if [ -z "$SED" ]; then
  SED=$(command -p -v sed)
  export SED
fi
if [ -z "$HEAD" ]; then
  HEAD=$(command -p -v head)
  export HEAD
fi
if [ -z "$TAIL" ]; then
  TAIL=$(command -p -v tail)
  export TAIL
fi
if [ -z "$WC" ]; then
  WC=$(command -p -v wc)
  export WC
fi

export BATS_TEST_DIRNAME
export TEMP_STUBS=tmpstubs
export CAPTURE_FILE=${BATS_TEST_DIRNAME}/${TEMP_STUBS}/shellmock.out
export SHELLMOCK_CAPTURE_ERR=${BATS_TEST_DIRNAME}/${TEMP_STUBS}/shellmock.err
export SHELLMOCK_CAPTURE_DEBUG=${BATS_TEST_DIRNAME}/shellmock-debug.out
export PATH=${BATS_TEST_DIRNAME}/${TEMP_STUBS}:$PATH

if [ -n "$SHELLMOCK_V1_COMPATIBILITY" ]; then
  shellmock_debug "shellmock: init: Running in V1 compatibility mode."
fi
