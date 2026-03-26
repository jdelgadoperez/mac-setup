######################################################################################
# Job Application Tracker
# CLI tool for tracking job applications via markdown
######################################################################################

function jobtrack() {
  local JOBTRACK_FILE="$HOME/projects/job-hunt/applications.md"
  local JOBTRACK_STATUSES=("applied" "screened" "interviewed" "offered" "rejected" "ghosted" "withdrawn")

  # Ensure tracker file exists
  _jobtrack_ensure_file() {
    if [[ ! -f "$JOBTRACK_FILE" ]]; then
      mkdir -p "$(dirname "$JOBTRACK_FILE")"
      printf '%s\n' \
        "# Job Applications" \
        "" \
        "> Tracked via \`jobtrack\` CLI. Each entry is an H2 section with structured fields." \
        "> Statuses: applied, screened, interviewed, offered, rejected, ghosted, withdrawn" \
        "" \
        "---" \
        > "$JOBTRACK_FILE"
    fi
  }

  # Color a status string
  _jobtrack_color_status() {
    local entry_status="${(L)1}"
    case "$entry_status" in
      applied)      echo -e "${CYAN}$1${NC}" ;;
      screened)     echo -e "${YELLOW}$1${NC}" ;;
      interviewed)  echo -e "${BLUE}$1${NC}" ;;
      offered)      echo -e "${GREEN}$1${NC}" ;;
      rejected)     echo -e "${RED}$1${NC}" ;;
      ghosted)      echo -e "${MAGENTA}$1${NC}" ;;
      withdrawn)    echo -e "${YELLOW}$1${NC}" ;;
      *)            echo -e "$1" ;;
    esac
  }

  # Find a company entry by partial match. Sets JOBTRACK_MATCH_LINE and JOBTRACK_MATCH_END.
  _jobtrack_find() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
      echo -e "${RED}Error: Company name required${NC}"
      return 1
    fi

    _jobtrack_ensure_file

    local -a match_lines match_texts
    local line_num line_text

    while IFS=: read -r line_num line_text; do
      match_lines+=("$line_num")
      match_texts+=("$line_text")
    done < <(grep -inF "$search_term" "$JOBTRACK_FILE" | grep '^[0-9]*:## ')

    if [[ ${#match_lines[@]} -eq 0 ]]; then
      echo -e "${RED}No applications found matching '${search_term}'${NC}"
      echo -e "Use ${CYAN}jt list${NC} to see all applications"
      return 1
    fi

    if [[ ${#match_lines[@]} -eq 1 ]]; then
      JOBTRACK_MATCH_LINE="${match_lines[1]}"
    else
      echo -e "\n${BOLD}Multiple matches found:${NC}"
      local i
      for i in {1..${#match_lines[@]}}; do
        local display="${match_texts[$i]#\#\# }"
        echo -e "  ${YELLOW}$i${NC}) $display"
      done
      echo ""
      local selection
      read -r "selection?Select entry [1-${#match_lines[@]}]: "
      if [[ ! "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#match_lines[@]} )); then
        echo -e "${RED}Invalid selection${NC}"
        return 1
      fi
      JOBTRACK_MATCH_LINE="${match_lines[$selection]}"
    fi

    # Find section end (next ## or EOF)
    JOBTRACK_MATCH_END=$(awk -v start="$((JOBTRACK_MATCH_LINE + 1))" 'NR >= start && /^## / { print NR - 1; exit }' "$JOBTRACK_FILE")
    if [[ -z "$JOBTRACK_MATCH_END" ]]; then
      JOBTRACK_MATCH_END=$(wc -l < "$JOBTRACK_FILE" | tr -d ' ')
    fi

    return 0
  }

  # Show help
  _jobtrack_help() {
    echo -e "${BOLD}${CYAN}jobtrack${NC} - Job application tracker CLI\n"
    echo -e "${BOLD}Usage:${NC} jobtrack <command> [options]"
    echo -e "       ${BOLD}jt${NC} <command> [options]\n"
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}add${NC}                          Add a new application (interactive)"
    echo -e "  ${GREEN}list${NC} [status]                 List applications, optionally filtered by status"
    echo -e "  ${GREEN}status${NC} <company> <status>     Update application status"
    echo -e "  ${GREEN}note${NC} <company> <text>         Add a timestamped note"
    echo -e "  ${GREEN}stats${NC}                         Show summary counts by status"
    echo -e "  ${GREEN}search${NC} <term>                 Search applications by keyword"
    echo -e "  ${GREEN}open${NC} <company>                Open job posting URL in browser"
    echo -e "  ${GREEN}edit${NC}                          Open tracker file in editor"
    echo -e "  ${GREEN}help${NC}                          Show this help message\n"
    echo -e "${BOLD}Statuses:${NC}"
    echo -e "  ${CYAN}applied${NC}  ${YELLOW}screened${NC}  ${BLUE}interviewed${NC}  ${GREEN}offered${NC}  ${RED}rejected${NC}  ${MAGENTA}ghosted${NC}  ${YELLOW}withdrawn${NC}\n"
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${CYAN}jt add${NC}                       → Add a new application"
    echo -e "  ${CYAN}jt list${NC}                      → Show all applications"
    echo -e "  ${CYAN}jt list applied${NC}              → Show only applied"
    echo -e "  ${CYAN}jt status acme screened${NC}      → Update Acme Corp to screened"
    echo -e "  ${CYAN}jt note acme \"Phone screen\"${NC}  → Add note to Acme entry"
    echo -e "  ${CYAN}jt stats${NC}                     → Show status summary"
    echo -e "  ${CYAN}jt search engineer${NC}           → Search all entries"
    echo -e "  ${CYAN}jt open acme${NC}                 → Open job posting in browser"
    echo -e "  ${CYAN}jt edit${NC}                      → Open file in editor\n"
  }

  # Add a new application
  _jobtrack_add() {
    _jobtrack_ensure_file

    echo -e "\n${BOLD}${CYAN}Add New Application${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    local company role url source_field salary recruiter

    read -r "company?${BOLD}Company name:${NC} "
    if [[ -z "$company" ]]; then
      echo -e "${RED}Error: Company name is required${NC}"
      return 1
    fi

    read -r "role?${BOLD}Role title:${NC} "
    if [[ -z "$role" ]]; then
      echo -e "${RED}Error: Role title is required${NC}"
      return 1
    fi

    read -r "url?${BOLD}URL (Enter to skip):${NC} "
    read -r "source_field?${BOLD}Source (Enter to skip):${NC} "
    read -r "salary?${BOLD}Salary range (Enter to skip):${NC} "
    read -r "recruiter?${BOLD}Recruiter (Enter to skip):${NC} "

    local today
    today=$(date +%Y-%m-%d)

    # Build the entry
    local entry="\n## ${company} | ${role}"
    entry+="\n- **Status:** Applied"
    entry+="\n- **Date Applied:** ${today}"
    [[ -n "$url" ]] && entry+="\n- **URL:** ${url}"
    [[ -n "$source_field" ]] && entry+="\n- **Source:** ${source_field}"
    [[ -n "$salary" ]] && entry+="\n- **Salary Range:** ${salary}"
    [[ -n "$recruiter" ]] && entry+="\n- **Recruiter:** ${recruiter}"
    entry+="\n- **Notes:**"
    entry+="\n  - [${today}] Applied"

    printf '%b\n' "$entry" >> "$JOBTRACK_FILE"

    echo -e "\n${BOLD}${GREEN}Added:${NC} ${company} | ${role}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  }

  # List applications
  _jobtrack_list() {
    _jobtrack_ensure_file

    local filter="${(L)1}"
    local has_entries=false

    # Validate filter if provided
    if [[ -n "$filter" ]]; then
      local valid=false
      for s in "${JOBTRACK_STATUSES[@]}"; do
        if [[ "$s" == "$filter" ]]; then
          valid=true
          break
        fi
      done
      if [[ "$valid" == false ]]; then
        echo -e "${RED}Invalid status: ${filter}${NC}"
        echo -e "Valid statuses: ${CYAN}${(j:, :)JOBTRACK_STATUSES}${NC}"
        return 1
      fi
    fi

    local -a companies roles statuses dates
    local current_company current_role current_status current_date

    while IFS= read -r line; do
      if [[ "$line" == "## "* ]]; then
        # Save previous entry if exists
        if [[ -n "$current_company" ]]; then
          companies+=("$current_company")
          roles+=("$current_role")
          statuses+=("$current_status")
          dates+=("$current_date")
        fi
        local header="${line#\#\# }"
        current_company="${header%% |*}"
        current_role="${header#*| }"
        current_status=""
        current_date=""
      elif [[ "$line" == "- **Status:** "* ]]; then
        current_status="${line#- \*\*Status:\*\* }"
      elif [[ "$line" == "- **Date Applied:** "* ]]; then
        current_date="${line#- \*\*Date Applied:\*\* }"
      fi
    done < "$JOBTRACK_FILE"

    # Save last entry
    if [[ -n "$current_company" ]]; then
      companies+=("$current_company")
      roles+=("$current_role")
      statuses+=("$current_status")
      dates+=("$current_date")
    fi

    if [[ ${#companies[@]} -eq 0 ]]; then
      echo -e "\n${YELLOW}No applications tracked yet${NC}"
      echo -e "Use ${CYAN}jt add${NC} to add your first application\n"
      return 0
    fi

    # Header
    echo ""
    if [[ -n "$filter" ]]; then
      echo -e "${BOLD}${CYAN}Applications — ${filter}${NC}"
    else
      echo -e "${BOLD}${CYAN}All Applications${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  ${BOLD}%-25s %-30s %-15s %s${NC}\n" "Company" "Role" "Status" "Date"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local count=0
    for i in {1..${#companies[@]}}; do
      local entry_status="${(L)statuses[$i]}"
      if [[ -n "$filter" && "$entry_status" != "$filter" ]]; then
        continue
      fi
      local colored_status=$(_jobtrack_color_status "${statuses[$i]}")
      printf "  %-25s %-30s %-24b %s\n" "${companies[$i]:0:24}" "${roles[$i]:0:29}" "$colored_status" "${dates[$i]}"
      count=$((count + 1))
      has_entries=true
    done

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Total:${NC} ${YELLOW}${count}${NC}\n"

    if [[ "$has_entries" == false ]]; then
      echo -e "  ${YELLOW}No applications with status '${filter}'${NC}\n"
    fi
  }

  # Update status
  _jobtrack_status() {
    local company="$1"
    local new_status="${(L)2}"

    if [[ -z "$company" || -z "$new_status" ]]; then
      echo -e "${RED}Usage: jt status <company> <new-status>${NC}"
      return 1
    fi

    # Validate status
    local valid=false
    for s in "${JOBTRACK_STATUSES[@]}"; do
      if [[ "$s" == "$new_status" ]]; then
        valid=true
        break
      fi
    done
    if [[ "$valid" == false ]]; then
      echo -e "${RED}Invalid status: ${new_status}${NC}"
      echo -e "Valid statuses: ${CYAN}${(j:, :)JOBTRACK_STATUSES}${NC}"
      return 1
    fi

    # Capitalize first letter for display
    local display_status="${(C)new_status}"

    _jobtrack_find "$company" || return 1

    local start="$JOBTRACK_MATCH_LINE"
    local end="$JOBTRACK_MATCH_END"

    # Get current status
    local old_status
    old_status=$(sed -n "${start},${end}p" "$JOBTRACK_FILE" | grep '^\- \*\*Status:\*\*' | head -1 | sed 's/.*\*\* //')

    # Update the status line
    local status_line
    status_line=$(awk -v start="$start" -v end="$end" '/^\- \*\*Status:\*\*/ && NR >= start && NR <= end { print NR; exit }' "$JOBTRACK_FILE")

    if [[ -n "$status_line" ]]; then
      sed -i '' "${status_line}s/.*$/- **Status:** ${display_status}/" "$JOBTRACK_FILE"
    fi

    # Add timestamped note about the change
    local today
    today=$(date +%Y-%m-%d)
    local note_text="Status changed from ${old_status} to ${display_status}"

    # Find the last note line in this section
    local last_note_line
    last_note_line=$(sed -n "${start},${end}p" "$JOBTRACK_FILE" | grep -n '^  - \[' | tail -1 | cut -d: -f1)

    if [[ -n "$last_note_line" ]]; then
      local absolute_line=$((start - 1 + last_note_line))
      sed -i '' "${absolute_line}a\\
  - [${today}] ${note_text}" "$JOBTRACK_FILE"
    else
      # Find the Notes: line and add after it
      local notes_line
      notes_line=$(awk -v start="$start" -v end="$end" '/^\- \*\*Notes:\*\*/ && NR >= start && NR <= end { print NR; exit }' "$JOBTRACK_FILE")
      if [[ -n "$notes_line" ]]; then
        sed -i '' "${notes_line}a\\
  - [${today}] ${note_text}" "$JOBTRACK_FILE"
      fi
    fi

    echo -e "\n${BOLD}${GREEN}Updated:${NC} $(_jobtrack_color_status "$old_status") → $(_jobtrack_color_status "$display_status")"
    # Extract company name from the matched line
    local matched_header
    matched_header=$(sed -n "${start}p" "$JOBTRACK_FILE" | sed 's/^## //')
    echo -e "${BOLD}Entry:${NC} ${matched_header}\n"
  }

  # Add a note
  _jobtrack_note() {
    local company="$1"
    shift
    local note_text="$*"

    if [[ -z "$company" || -z "$note_text" ]]; then
      echo -e "${RED}Usage: jt note <company> <note text>${NC}"
      return 1
    fi

    _jobtrack_find "$company" || return 1

    local start="$JOBTRACK_MATCH_LINE"
    local end="$JOBTRACK_MATCH_END"
    local today
    today=$(date +%Y-%m-%d)

    # Find the last note line in this section
    local last_note_line
    last_note_line=$(sed -n "${start},${end}p" "$JOBTRACK_FILE" | grep -n '^  - \[' | tail -1 | cut -d: -f1)

    if [[ -n "$last_note_line" ]]; then
      local absolute_line=$((start - 1 + last_note_line))
      sed -i '' "${absolute_line}a\\
  - [${today}] ${note_text}" "$JOBTRACK_FILE"
    else
      # Find the Notes: line and add after it
      local notes_line
      notes_line=$(awk -v start="$start" -v end="$end" '/^\- \*\*Notes:\*\*/ && NR >= start && NR <= end { print NR; exit }' "$JOBTRACK_FILE")
      if [[ -n "$notes_line" ]]; then
        sed -i '' "${notes_line}a\\
  - [${today}] ${note_text}" "$JOBTRACK_FILE"
      fi
    fi

    local matched_header
    matched_header=$(sed -n "${start}p" "$JOBTRACK_FILE" | sed 's/^## //')
    echo -e "\n${BOLD}${GREEN}Note added:${NC} ${matched_header}"
    echo -e "  ${CYAN}[${today}]${NC} ${note_text}\n"
  }

  # Show stats
  _jobtrack_stats() {
    _jobtrack_ensure_file

    local total=0
    local -A counts

    while IFS= read -r line; do
      if [[ "$line" == "- **Status:** "* ]]; then
        local entry_status="${(L)${line#- \*\*Status:\*\* }}"
        counts[$entry_status]=$(( ${counts[$entry_status]:-0} + 1 ))
        total=$((total + 1))
      fi
    done < "$JOBTRACK_FILE"

    if [[ $total -eq 0 ]]; then
      echo -e "\n${YELLOW}No applications tracked yet${NC}"
      echo -e "Use ${CYAN}jt add${NC} to add your first application\n"
      return 0
    fi

    echo -e "\n${BOLD}${CYAN}Application Stats${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    for s in "${JOBTRACK_STATUSES[@]}"; do
      local count=${counts[$s]:-0}
      if [[ $count -gt 0 ]]; then
        local colored=$(_jobtrack_color_status "${(C)s}")
        printf "  %-24b %s\n" "$colored" "${BOLD}${count}${NC}"
      fi
    done

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Total${NC}                  ${BOLD}${YELLOW}${total}${NC}\n"
  }

  # Search applications
  _jobtrack_search() {
    local term="$1"
    if [[ -z "$term" ]]; then
      echo -e "${RED}Usage: jt search <term>${NC}"
      return 1
    fi

    _jobtrack_ensure_file

    # Find all line numbers with matches
    local -a match_line_nums
    while IFS=: read -r line_num _; do
      match_line_nums+=("$line_num")
    done < <(grep -inF "$term" "$JOBTRACK_FILE")

    if [[ ${#match_line_nums[@]} -eq 0 ]]; then
      echo -e "\n${YELLOW}No results for '${term}'${NC}\n"
      return 0
    fi

    # Find all H2 line numbers
    local -a h2_lines
    while IFS=: read -r line_num _; do
      h2_lines+=("$line_num")
    done < <(grep -n '^## ' "$JOBTRACK_FILE")

    # For each match, find the parent H2 section
    local -a section_starts
    for match_ln in "${match_line_nums[@]}"; do
      local parent_h2=""
      for h2_ln in "${h2_lines[@]}"; do
        if (( h2_ln <= match_ln )); then
          parent_h2="$h2_ln"
        else
          break
        fi
      done
      if [[ -n "$parent_h2" ]]; then
        # Deduplicate
        local already_added=false
        for existing in "${section_starts[@]}"; do
          if [[ "$existing" == "$parent_h2" ]]; then
            already_added=true
            break
          fi
        done
        if [[ "$already_added" == false ]]; then
          section_starts+=("$parent_h2")
        fi
      fi
    done

    echo -e "\n${BOLD}${CYAN}Search results for '${term}'${NC} (${#section_starts[@]} found)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local total_lines
    total_lines=$(wc -l < "$JOBTRACK_FILE" | tr -d ' ')

    for section_start in "${section_starts[@]}"; do
      # Find section end
      local section_end="$total_lines"
      for h2_ln in "${h2_lines[@]}"; do
        if (( h2_ln > section_start )); then
          section_end=$((h2_ln - 1))
          break
        fi
      done

      echo ""
      sed -n "${section_start},${section_end}p" "$JOBTRACK_FILE"
    done

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  }

  # Open job posting URL
  _jobtrack_open() {
    local company="$1"
    if [[ -z "$company" ]]; then
      echo -e "${RED}Usage: jt open <company>${NC}"
      return 1
    fi

    _jobtrack_find "$company" || return 1

    local start="$JOBTRACK_MATCH_LINE"
    local end="$JOBTRACK_MATCH_END"

    local url
    url=$(sed -n "${start},${end}p" "$JOBTRACK_FILE" | grep '^\- \*\*URL:\*\*' | head -1 | sed 's/.*\*\* //')

    if [[ -z "$url" ]]; then
      local matched_header
      matched_header=$(sed -n "${start}p" "$JOBTRACK_FILE" | sed 's/^## //')
      echo -e "\n${YELLOW}No URL found for: ${matched_header}${NC}\n"
      return 1
    fi

    echo -e "\n${GREEN}Opening:${NC} ${url}\n"
    open "$url"
  }

  # Open tracker file in editor
  _jobtrack_edit() {
    _jobtrack_ensure_file
    ${EDITOR:-vim} "$JOBTRACK_FILE"
  }

  # Main command dispatch
  case "$1" in
    -h|--help|help)
      _jobtrack_help
      ;;
    add)
      shift
      _jobtrack_add "$@"
      ;;
    list|ls)
      shift
      _jobtrack_list "$@"
      ;;
    status)
      shift
      _jobtrack_status "$@"
      ;;
    note)
      shift
      _jobtrack_note "$@"
      ;;
    stats)
      _jobtrack_stats
      ;;
    search|find)
      shift
      _jobtrack_search "$@"
      ;;
    open)
      shift
      _jobtrack_open "$@"
      ;;
    edit)
      _jobtrack_edit
      ;;
    *)
      _jobtrack_help
      ;;
  esac
}

alias jt="jobtrack"
