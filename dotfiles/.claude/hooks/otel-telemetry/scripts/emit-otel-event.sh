#!/bin/bash
# @hook-event: SubagentStart,SubagentStop,PreToolUse
# @hook-command: ~/.claude/hooks/otel-telemetry/scripts/emit-otel-event.sh
# @description: Emits OTLP log events + trace spans for subagent lifecycle and tool calls
#
# Usage: emit-otel-event.sh <EventType>
# Receives hook JSON on stdin, builds OTLP payloads, POSTs to collector.
#
# Events:
#   SubagentStart    — log + state file (span start time)
#   SubagentStop     — log + parent span + child spans from transcript parsing
#   AgentInvocation  — log only (PreToolUse on Agent tool)

set -euo pipefail

EVENT_TYPE="${1:-unknown}"
OTEL_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
LOG_FILE="${OTEL_HOOK_LOG_FILE:-/tmp/otel-subagent-hook.log}"
STATE_DIR="${OTEL_HOOK_STATE_DIR:-/tmp/otel-subagent-state}"

mkdir -p "$STATE_DIR"

log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$EVENT_TYPE] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Read hook JSON from stdin
INPUT=$(cat)
if [ -z "$INPUT" ]; then
  log "No input received"
  exit 0
fi

# Generate timestamp in nanoseconds
TIMESTAMP_NS=$(/usr/bin/python3 -c "import time; print(int(time.time() * 1e9))" 2>/dev/null || echo "0")

# Extract common fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Deterministic ID generation
generate_trace_id() {
  echo -n "$1" | md5 | head -c 32
}

generate_span_id() {
  echo -n "$1" | md5 | head -c 16
}

# Convert ISO timestamp to nanoseconds
iso_to_ns() {
  /usr/bin/python3 -c "
from datetime import datetime, timezone
ts = '$1'
dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
print(int(dt.timestamp() * 1e9))
" 2>/dev/null || echo "0"
}

# --- Emit OTLP Log ---
emit_log() {
  local event_name="$1"
  local body="$2"
  local extra_attrs="$3"

  local trace_id
  trace_id=$(generate_trace_id "$SESSION_ID")

  local common_attrs
  common_attrs=$(jq -n \
    --arg en "$event_name" \
    --arg sid "$SESSION_ID" \
    --arg aid "$AGENT_ID" \
    --arg at "$AGENT_TYPE" \
    --arg cwd "$CWD" \
    --arg tid "$trace_id" \
    '[
      {"key": "event_name", "value": {"stringValue": $en}},
      {"key": "session_id", "value": {"stringValue": $sid}},
      {"key": "agent.id", "value": {"stringValue": $aid}},
      {"key": "agent.type", "value": {"stringValue": $at}},
      {"key": "cwd", "value": {"stringValue": $cwd}},
      {"key": "trace_id", "value": {"stringValue": $tid}}
    ]')

  local all_attrs
  all_attrs=$(echo "$common_attrs" "$extra_attrs" | jq -s 'add')

  local payload
  payload=$(jq -n \
    --arg ts "$TIMESTAMP_NS" \
    --arg body "$body" \
    --argjson attrs "$all_attrs" \
    '{
      "resourceLogs": [{
        "resource": {
          "attributes": [
            {"key": "service.name", "value": {"stringValue": "claude-code"}}
          ]
        },
        "scopeLogs": [{
          "scope": {"name": "claude.code.hooks", "version": "1.0.0"},
          "logRecords": [{
            "timeUnixNano": $ts,
            "severityNumber": 9,
            "severityText": "INFO",
            "body": {"stringValue": $body},
            "attributes": $attrs
          }]
        }]
      }]
    }')

  curl -s -o /dev/null \
    -X POST "${OTEL_ENDPOINT}/v1/logs" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --connect-timeout 3 \
    --max-time 5 2>/dev/null || true
}

# --- Emit OTLP Trace Span ---
# Args: trace_id span_id span_name start_ns end_ns span_attrs [parent_span_id] [status_code] [status_message]
emit_trace_span() {
  local trace_id="$1"
  local span_id="$2"
  local span_name="$3"
  local start_ns="$4"
  local end_ns="$5"
  local span_attrs="$6"
  local parent_span_id="${7:-}"
  local status_code="${8:-1}"    # 1=OK, 2=ERROR
  local status_message="${9:-}"

  local status_obj
  if [ -n "$status_message" ]; then
    status_obj=$(jq -n --arg code "$status_code" --arg msg "$status_message" '{code: ($code | tonumber), message: $msg}')
  else
    status_obj=$(jq -n --arg code "$status_code" '{code: ($code | tonumber)}')
  fi

  local payload
  if [ -n "$parent_span_id" ]; then
    payload=$(jq -n \
      --arg tid "$trace_id" \
      --arg sid "$span_id" \
      --arg psid "$parent_span_id" \
      --arg name "$span_name" \
      --arg start "$start_ns" \
      --arg end "$end_ns" \
      --argjson attrs "$span_attrs" \
      --argjson status "$status_obj" \
      '{
        "resourceSpans": [{
          "resource": {
            "attributes": [
              {"key": "service.name", "value": {"stringValue": "claude-code"}}
            ]
          },
          "scopeSpans": [{
            "scope": {"name": "claude.code.hooks", "version": "1.0.0"},
            "spans": [{
              "traceId": $tid,
              "spanId": $sid,
              "parentSpanId": $psid,
              "name": $name,
              "kind": 1,
              "startTimeUnixNano": $start,
              "endTimeUnixNano": $end,
              "status": $status,
              "attributes": $attrs
            }]
          }]
        }]
      }')
  else
    payload=$(jq -n \
      --arg tid "$trace_id" \
      --arg sid "$span_id" \
      --arg name "$span_name" \
      --arg start "$start_ns" \
      --arg end "$end_ns" \
      --argjson attrs "$span_attrs" \
      --argjson status "$status_obj" \
      '{
        "resourceSpans": [{
          "resource": {
            "attributes": [
              {"key": "service.name", "value": {"stringValue": "claude-code"}}
            ]
          },
          "scopeSpans": [{
            "scope": {"name": "claude.code.hooks", "version": "1.0.0"},
            "spans": [{
              "traceId": $tid,
              "spanId": $sid,
              "name": $name,
              "kind": 1,
              "startTimeUnixNano": $start,
              "endTimeUnixNano": $end,
              "status": $status,
              "attributes": $attrs
            }]
          }]
        }]
      }')
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${OTEL_ENDPOINT}/v1/traces" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --connect-timeout 3 \
    --max-time 5 2>/dev/null || echo "000")

  if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
    log "TRACE OK trace=$trace_id span=$span_id parent=${parent_span_id:-root} name=$span_name"
  else
    log "TRACE FAIL http=$http_code trace=$trace_id span=$span_id"
  fi
}

# --- Fetch decision_source map from Loki ---
fetch_decision_map() {
  local session_id="$1"
  local loki_url="${LOKI_URL:-http://localhost:3100}"
  local start_ns end_ns

  # Query window: 24h back from now
  start_ns=$(/usr/bin/python3 -c "import time; print(int((time.time() - 86400) * 1e9))" 2>/dev/null || echo "0")
  end_ns=$(/usr/bin/python3 -c "import time; print(int(time.time() * 1e9))" 2>/dev/null || echo "0")

  curl -s "${loki_url}/loki/api/v1/query_range" \
    --data-urlencode "query={service_name=\"claude-code\"} | session_id=\"${session_id}\" | event_name=\"tool_result\"" \
    --data-urlencode "limit=200" \
    --data-urlencode "start=${start_ns}" \
    --data-urlencode "end=${end_ns}" \
    --connect-timeout 3 \
    --max-time 10 2>/dev/null | \
    jq -c '[.data.result[] | {ts_sec: (.stream.event_timestamp | .[0:19]), tool: .stream.tool_name, decision: .stream.decision_source}]' 2>/dev/null || echo "[]"
}

# --- Parse transcript and emit child spans ---
emit_tool_spans_from_transcript() {
  local transcript_path="$1"
  local trace_id="$2"
  local parent_span_id="$3"

  if [ ! -f "$transcript_path" ]; then
    log "TRANSCRIPT not found: $transcript_path"
    return
  fi

  # Fetch decision_source map from Loki for this session
  local decision_map
  decision_map=$(fetch_decision_map "$SESSION_ID")
  local decision_count
  decision_count=$(echo "$decision_map" | jq 'length' 2>/dev/null || echo "0")
  log "DECISION MAP fetched $decision_count entries for session=$SESSION_ID"

  # Save decision map to temp file for Python to read
  local decision_file="/tmp/otel-decision-map-$$.json"
  echo "$decision_map" > "$decision_file"

  # Extract tool pairs from transcript + match decisions
  local tool_pairs
  tool_pairs=$(/usr/bin/python3 -c "
import json, sys

# Load decision map
with open('$decision_file') as f:
    decision_raw = json.load(f)
decision_lookup = {}
for d in decision_raw:
    key = (d['ts_sec'], d['tool'])
    decision_lookup[key] = d['decision']

starts = {}
pairs = []

with open('$transcript_path') as f:
    for line in f:
        try:
            entry = json.loads(line)
        except:
            continue
        ts = entry.get('timestamp', '')
        msg = entry.get('message', {})
        contents = msg.get('content', [])
        if not isinstance(contents, list):
            continue
        for block in contents:
            if not isinstance(block, dict):
                continue
            if block.get('type') == 'tool_use':
                tool_id = block.get('id', '')
                tool_name = block.get('name', '')
                tool_input = block.get('input', {})
                summary = ''
                if tool_name == 'Bash':
                    summary = (tool_input.get('command') or '')[:80]
                elif tool_name in ('Read', 'Write', 'Edit'):
                    fp = tool_input.get('file_path', '')
                    summary = fp.split('/')[-1] if fp else ''
                elif tool_name in ('Grep', 'Glob'):
                    summary = (tool_input.get('pattern') or '')[:40]
                elif tool_name == 'WebSearch':
                    summary = (tool_input.get('query') or '')[:40]
                elif tool_name == 'WebFetch':
                    summary = (tool_input.get('url') or '')[:60]
                starts[tool_id] = {'name': tool_name, 'ts': ts, 'summary': summary}
            elif block.get('type') == 'tool_result':
                tool_id = block.get('tool_use_id', '')
                is_error = block.get('is_error', False)
                if tool_id in starts:
                    s = starts[tool_id]
                    # Match decision from Loki by end timestamp + tool name
                    end_sec = ts[:19]
                    decision = decision_lookup.get((end_sec, s['name']), 'unknown')
                    pairs.append({
                        'id': tool_id,
                        'name': s['name'],
                        'summary': s['summary'],
                        'start_ts': s['ts'],
                        'end_ts': ts,
                        'is_error': is_error,
                        'decision': decision
                    })

json.dump(pairs, sys.stdout)
" 2>/dev/null) || { rm -f "$decision_file"; return; }

  rm -f "$decision_file"

  local pair_count
  pair_count=$(echo "$tool_pairs" | jq 'length')

  if [ "$pair_count" = "0" ] || [ -z "$pair_count" ]; then
    log "TRANSCRIPT no tool pairs found in $transcript_path"
    return
  fi

  log "TRANSCRIPT found $pair_count tool pairs in $transcript_path"

  # Emit a child span for each tool pair
  local i=0
  while [ "$i" -lt "$pair_count" ]; do
    local tool_id tool_name summary start_ts end_ts is_error decision
    tool_id=$(echo "$tool_pairs" | jq -r ".[$i].id")
    tool_name=$(echo "$tool_pairs" | jq -r ".[$i].name")
    summary=$(echo "$tool_pairs" | jq -r ".[$i].summary")
    start_ts=$(echo "$tool_pairs" | jq -r ".[$i].start_ts")
    end_ts=$(echo "$tool_pairs" | jq -r ".[$i].end_ts")
    is_error=$(echo "$tool_pairs" | jq -r ".[$i].is_error")
    decision=$(echo "$tool_pairs" | jq -r ".[$i].decision")

    # Convert ISO timestamps to nanoseconds
    local start_ns end_ns
    start_ns=$(iso_to_ns "$start_ts")
    end_ns=$(iso_to_ns "$end_ts")

    # Build span name — prefix with [PROMPTED] for user-prompted tools
    local span_name="$tool_name"
    local user_prompted="false"
    if [ "$decision" = "user_temporary" ]; then
      user_prompted="true"
      if [ -n "$summary" ]; then
        span_name="[PROMPTED] $tool_name: $summary"
      else
        span_name="[PROMPTED] $tool_name"
      fi
    elif [ -n "$summary" ]; then
      span_name="$tool_name: $summary"
    fi

    # Determine status
    local status_code="1"
    local status_message=""
    if [ "$is_error" = "true" ]; then
      status_code="2"
      status_message="Tool execution failed"
    fi

    # Generate unique span ID from tool_use_id
    local tool_span_id
    tool_span_id=$(generate_span_id "$tool_id")

    local span_attrs
    span_attrs=$(jq -n \
      --arg tn "$tool_name" \
      --arg tid "$tool_id" \
      --arg sid "$SESSION_ID" \
      --arg aid "$AGENT_ID" \
      --arg at "$AGENT_TYPE" \
      --arg err "$is_error" \
      --arg up "$user_prompted" \
      --arg ds "$decision" \
      '[
        {"key": "tool.name", "value": {"stringValue": $tn}},
        {"key": "tool.use_id", "value": {"stringValue": $tid}},
        {"key": "session.id", "value": {"stringValue": $sid}},
        {"key": "agent.id", "value": {"stringValue": $aid}},
        {"key": "agent.type", "value": {"stringValue": $at}},
        {"key": "tool.is_error", "value": {"stringValue": $err}},
        {"key": "tool.user_prompted", "value": {"stringValue": $up}},
        {"key": "tool.decision_source", "value": {"stringValue": $ds}}
      ]')

    emit_trace_span "$trace_id" "$tool_span_id" "$span_name" "$start_ns" "$end_ns" "$span_attrs" "$parent_span_id" "$status_code" "$status_message"

    i=$((i + 1))
  done
}

# --- Extract tool detail for span name ---
extract_tool_detail() {
  local tool_name="$1"
  local tool_input="$2"

  case "$tool_name" in
    Bash)
      echo "$tool_input" | jq -r '.command // ""' 2>/dev/null | head -c 80
      ;;
    Read|Write|Edit)
      local fp
      fp=$(echo "$tool_input" | jq -r '.file_path // ""' 2>/dev/null)
      echo "${fp##*/}"
      ;;
    Grep|Glob)
      echo "$tool_input" | jq -r '.pattern // ""' 2>/dev/null | head -c 40
      ;;
    WebSearch)
      echo "$tool_input" | jq -r '.query // ""' 2>/dev/null | head -c 40
      ;;
    WebFetch)
      echo "$tool_input" | jq -r '.url // ""' 2>/dev/null | head -c 60
      ;;
    Skill)
      echo "$tool_input" | jq -r '.skill // ""' 2>/dev/null
      ;;
    *)
      echo ""
      ;;
  esac
}

# --- Clean stale tool state files (older than 1 hour) ---
cleanup_stale_tool_files() {
  find "$STATE_DIR" -name "tool-*.json" -mmin +60 -delete 2>/dev/null || true
  find "$STATE_DIR" -name "active-subagent-*" -mmin +60 -delete 2>/dev/null || true
}

# --- Event Handlers ---
case "$EVENT_TYPE" in
  SubagentStart)
    emit_log "subagent_start" "claude_code.hook.subagent_start" "$(jq -n '[]')"

    # Write state file for SubagentStop to pick up
    if [ -n "$AGENT_ID" ]; then
      jq -n \
        --arg ts "$TIMESTAMP_NS" \
        --arg sid "$SESSION_ID" \
        --arg aid "$AGENT_ID" \
        --arg at "$AGENT_TYPE" \
        --arg cwd "$CWD" \
        '{start_ns: $ts, session_id: $sid, agent_id: $aid, agent_type: $at, cwd: $cwd}' \
        > "$STATE_DIR/$AGENT_ID.json"
      log "STATE wrote $STATE_DIR/$AGENT_ID.json"
      touch "$STATE_DIR/active-subagent-$AGENT_ID"
    fi
    ;;

  SubagentStop)
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // ""')
    LAST_MSG_LEN=$(echo "$INPUT" | jq -r '.last_assistant_message // "" | length')
    EXTRA_ATTRS=$(jq -n \
      --arg tp "$TRANSCRIPT_PATH" \
      --arg ml "$LAST_MSG_LEN" \
      '[
        {"key": "agent.transcript_path", "value": {"stringValue": $tp}},
        {"key": "agent.last_message_length", "value": {"intValue": $ml}}
      ]')
    emit_log "subagent_stop" "claude_code.hook.subagent_stop" "$EXTRA_ATTRS"

    # Emit parent trace span
    STATE_FILE="$STATE_DIR/$AGENT_ID.json"
    if [ -n "$AGENT_ID" ] && [ -f "$STATE_FILE" ]; then
      START_NS=$(jq -r '.start_ns' "$STATE_FILE")
      TRACE_ID=$(generate_trace_id "$SESSION_ID")
      SPAN_ID=$(generate_span_id "$AGENT_ID")

      SPAN_ATTRS=$(jq -n \
        --arg sid "$SESSION_ID" \
        --arg aid "$AGENT_ID" \
        --arg at "$AGENT_TYPE" \
        --arg cwd "$CWD" \
        --arg tp "$TRANSCRIPT_PATH" \
        --arg ml "$LAST_MSG_LEN" \
        '[
          {"key": "session.id", "value": {"stringValue": $sid}},
          {"key": "agent.id", "value": {"stringValue": $aid}},
          {"key": "agent.type", "value": {"stringValue": $at}},
          {"key": "cwd", "value": {"stringValue": $cwd}},
          {"key": "agent.transcript_path", "value": {"stringValue": $tp}},
          {"key": "agent.last_message_length", "value": {"intValue": $ml}}
        ]')

      emit_trace_span "$TRACE_ID" "$SPAN_ID" "subagent: $AGENT_TYPE" "$START_NS" "$TIMESTAMP_NS" "$SPAN_ATTRS"

      # Parse transcript and emit child tool spans
      if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        emit_tool_spans_from_transcript "$TRANSCRIPT_PATH" "$TRACE_ID" "$SPAN_ID"
      else
        # Try expanding ~ in path
        EXPANDED_PATH="${TRANSCRIPT_PATH/#\~/$HOME}"
        if [ -f "$EXPANDED_PATH" ]; then
          emit_tool_spans_from_transcript "$EXPANDED_PATH" "$TRACE_ID" "$SPAN_ID"
        else
          log "TRANSCRIPT not found at $TRANSCRIPT_PATH or $EXPANDED_PATH"
        fi
      fi

      rm -f "$STATE_FILE"
      rm -f "$STATE_DIR/active-subagent-$AGENT_ID"
      log "STATE cleaned $STATE_FILE"
    else
      log "STATE not found for agent_id=$AGENT_ID (no span emitted)"
    fi
    ;;

  AgentInvocation)
    SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')
    PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""')
    DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')
    MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // ""')
    if [ -z "$AGENT_TYPE" ]; then
      AGENT_TYPE="$SUBAGENT_TYPE"
    fi
    EXTRA_ATTRS=$(jq -n \
      --arg st "$SUBAGENT_TYPE" \
      --arg pr "$PROMPT" \
      --arg desc "$DESCRIPTION" \
      --arg model "$MODEL" \
      '[
        {"key": "agent.subagent_type", "value": {"stringValue": $st}},
        {"key": "agent.prompt", "value": {"stringValue": $pr}},
        {"key": "agent.description", "value": {"stringValue": $desc}},
        {"key": "agent.model", "value": {"stringValue": $model}}
      ]')
    emit_log "agent_invocation" "claude_code.hook.agent_invocation" "$EXTRA_ATTRS"
    ;;

  MainToolStart)
    # PreToolUse (no Agent matcher) — capture main agent tool start time
    TOOL_USE_ID=$(echo "$INPUT" | jq -r '.tool_use_id // ""')
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

    # Skip tools inside active subagents (marker file check) and Agent tool
    if ls "$STATE_DIR"/active-subagent-* 1>/dev/null 2>&1; then
      log "SKIP tool inside active subagent ($TOOL_NAME)"
      exit 0
    fi
    if [ "$TOOL_NAME" = "Agent" ]; then
      log "SKIP Agent tool (handled by AgentInvocation)"
      exit 0
    fi
    if [ -z "$TOOL_USE_ID" ]; then
      log "SKIP no tool_use_id"
      exit 0
    fi

    # Write state file for PostToolUse/PostToolUseFailure to pick up
    jq -n \
      --arg ts "$TIMESTAMP_NS" \
      --arg sid "$SESSION_ID" \
      --arg tn "$TOOL_NAME" \
      '{start_ns: $ts, session_id: $sid, tool_name: $tn}' \
      > "$STATE_DIR/tool-$TOOL_USE_ID.json"
    log "STATE wrote tool-$TOOL_USE_ID.json ($TOOL_NAME)"
    ;;

  MainToolEnd)
    # PostToolUse — emit trace span for main agent tool call (success)
    TOOL_USE_ID=$(echo "$INPUT" | jq -r '.tool_use_id // ""')
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
    TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

    # Skip tools inside active subagents and Agent tool
    if ls "$STATE_DIR"/active-subagent-* 1>/dev/null 2>&1; then exit 0; fi
    if [ "$TOOL_NAME" = "Agent" ]; then exit 0; fi
    if [ -z "$TOOL_USE_ID" ]; then exit 0; fi

    # Clean stale state files opportunistically
    cleanup_stale_tool_files

    STATE_FILE="$STATE_DIR/tool-$TOOL_USE_ID.json"
    if [ ! -f "$STATE_FILE" ]; then
      log "STATE missing for tool_use_id=$TOOL_USE_ID (no span emitted)"
      exit 0
    fi

    START_NS=$(jq -r '.start_ns' "$STATE_FILE")
    # Clamp: end must be >= start (Python startup jitter can invert fast tools)
    if [ "$TIMESTAMP_NS" -lt "$START_NS" ] 2>/dev/null || [ "$TIMESTAMP_NS" = "$START_NS" ]; then
      TIMESTAMP_NS=$((START_NS + 1000))
    fi
    TRACE_ID=$(generate_trace_id "$SESSION_ID")
    SPAN_ID=$(generate_span_id "$TOOL_USE_ID")

    # Build span name with detail
    DETAIL=$(extract_tool_detail "$TOOL_NAME" "$TOOL_INPUT")
    if [ -n "$DETAIL" ]; then
      SPAN_NAME="$TOOL_NAME: $DETAIL"
    else
      SPAN_NAME="$TOOL_NAME"
    fi

    SPAN_ATTRS=$(jq -n \
      --arg tn "$TOOL_NAME" \
      --arg tid "$TOOL_USE_ID" \
      --arg sid "$SESSION_ID" \
      --arg at "main" \
      --arg err "false" \
      --arg up "unknown" \
      --arg ds "unknown" \
      '[
        {"key": "tool.name", "value": {"stringValue": $tn}},
        {"key": "tool.use_id", "value": {"stringValue": $tid}},
        {"key": "session.id", "value": {"stringValue": $sid}},
        {"key": "agent.type", "value": {"stringValue": $at}},
        {"key": "tool.is_error", "value": {"stringValue": $err}},
        {"key": "tool.user_prompted", "value": {"stringValue": $up}},
        {"key": "tool.decision_source", "value": {"stringValue": $ds}}
      ]')

    # Emit root-level span (no parentSpanId)
    emit_trace_span "$TRACE_ID" "$SPAN_ID" "$SPAN_NAME" "$START_NS" "$TIMESTAMP_NS" "$SPAN_ATTRS" "" "1" ""

    # Emit log event
    EXTRA_ATTRS=$(jq -n \
      --arg tuid "$TOOL_USE_ID" \
      --arg tn "$TOOL_NAME" \
      '[
        {"key": "tool.use_id", "value": {"stringValue": $tuid}},
        {"key": "tool.name", "value": {"stringValue": $tn}}
      ]')
    emit_log "main_tool_end" "claude_code.hook.main_tool_end" "$EXTRA_ATTRS"

    rm -f "$STATE_FILE"
    log "TOOL SPAN OK tool=$TOOL_NAME id=$TOOL_USE_ID name=$SPAN_NAME"
    ;;

  MainToolError)
    # PostToolUseFailure — emit error trace span for main agent tool call
    TOOL_USE_ID=$(echo "$INPUT" | jq -r '.tool_use_id // ""')
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
    TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
    ERROR_MSG=$(echo "$INPUT" | jq -r '.error // "Unknown error"')
    IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')

    # Skip tools inside active subagents and Agent tool
    if ls "$STATE_DIR"/active-subagent-* 1>/dev/null 2>&1; then exit 0; fi
    if [ "$TOOL_NAME" = "Agent" ]; then exit 0; fi
    if [ -z "$TOOL_USE_ID" ]; then exit 0; fi

    cleanup_stale_tool_files

    STATE_FILE="$STATE_DIR/tool-$TOOL_USE_ID.json"
    if [ ! -f "$STATE_FILE" ]; then
      log "STATE missing for tool_use_id=$TOOL_USE_ID (no error span emitted)"
      exit 0
    fi

    START_NS=$(jq -r '.start_ns' "$STATE_FILE")
    # Clamp: end must be >= start (Python startup jitter can invert fast tools)
    if [ "$TIMESTAMP_NS" -lt "$START_NS" ] 2>/dev/null || [ "$TIMESTAMP_NS" = "$START_NS" ]; then
      TIMESTAMP_NS=$((START_NS + 1000))
    fi
    TRACE_ID=$(generate_trace_id "$SESSION_ID")
    SPAN_ID=$(generate_span_id "$TOOL_USE_ID")

    # Build span name with detail
    DETAIL=$(extract_tool_detail "$TOOL_NAME" "$TOOL_INPUT")
    if [ -n "$DETAIL" ]; then
      SPAN_NAME="$TOOL_NAME: $DETAIL"
    else
      SPAN_NAME="$TOOL_NAME"
    fi

    # Mark interrupted tools in span name
    if [ "$IS_INTERRUPT" = "true" ]; then
      SPAN_NAME="[INTERRUPTED] $SPAN_NAME"
    fi

    SPAN_ATTRS=$(jq -n \
      --arg tn "$TOOL_NAME" \
      --arg tid "$TOOL_USE_ID" \
      --arg sid "$SESSION_ID" \
      --arg at "main" \
      --arg err "true" \
      --arg up "unknown" \
      --arg ds "unknown" \
      --arg emsg "$ERROR_MSG" \
      --arg intr "$IS_INTERRUPT" \
      '[
        {"key": "tool.name", "value": {"stringValue": $tn}},
        {"key": "tool.use_id", "value": {"stringValue": $tid}},
        {"key": "session.id", "value": {"stringValue": $sid}},
        {"key": "agent.type", "value": {"stringValue": $at}},
        {"key": "tool.is_error", "value": {"stringValue": $err}},
        {"key": "tool.user_prompted", "value": {"stringValue": $up}},
        {"key": "tool.decision_source", "value": {"stringValue": $ds}},
        {"key": "tool.error_message", "value": {"stringValue": $emsg}},
        {"key": "tool.is_interrupt", "value": {"stringValue": $intr}}
      ]')

    # Emit root-level error span
    emit_trace_span "$TRACE_ID" "$SPAN_ID" "$SPAN_NAME" "$START_NS" "$TIMESTAMP_NS" "$SPAN_ATTRS" "" "2" "$ERROR_MSG"

    # Emit log event
    EXTRA_ATTRS=$(jq -n \
      --arg tuid "$TOOL_USE_ID" \
      --arg tn "$TOOL_NAME" \
      --arg emsg "$ERROR_MSG" \
      --arg intr "$IS_INTERRUPT" \
      '[
        {"key": "tool.use_id", "value": {"stringValue": $tuid}},
        {"key": "tool.name", "value": {"stringValue": $tn}},
        {"key": "tool.error_message", "value": {"stringValue": $emsg}},
        {"key": "tool.is_interrupt", "value": {"stringValue": $intr}}
      ]')
    emit_log "main_tool_error" "claude_code.hook.main_tool_error" "$EXTRA_ATTRS"

    rm -f "$STATE_FILE"
    log "TOOL ERROR SPAN OK tool=$TOOL_NAME id=$TOOL_USE_ID error=$ERROR_MSG"
    ;;

  *)
    log "Unknown event type: $EVENT_TYPE"
    exit 0
    ;;
esac

exit 0
