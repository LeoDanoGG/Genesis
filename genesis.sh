#!/bin/bash

# ==============================================================================
# Genesis - Interactive project scaffolder for 42 School students
#
#   genesis                      Interactive wizard
#   genesis fast [name] [url]    Quick start: answers come from genesis.conf
#   genesis sync                 Refresh SRCS and the README file list right here
# ==============================================================================

BLUE="\033[34m"; GREEN="\033[32m"; YELLOW="\033[33m"
RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"

# Messages go through %s so nothing inside them is ever interpreted.
info() { printf '%b[+] %s%b\n' "$BLUE" "$1" "$RESET"; }
ok()   { printf '%b✔ %s%b\n' "$GREEN" "$1" "$RESET"; }
warn() { printf '%b[!] %s%b\n' "$YELLOW" "$1" "$RESET"; }
err()  { printf '%bError: %s%b\n' "$RED" "$1" "$RESET"; }

usage() {
    cat << 'EOF'
Usage:
  genesis                       Interactive wizard
  genesis fast [name] [url]     Quick start using genesis.conf (no questions)
  genesis default [name] [url]  Same as 'fast'
  genesis sync                  Update SRCS and README file list in this directory
EOF
}

# ==============================================================================
# HELPERS
# ==============================================================================

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

valid_name()   { [[ "$1" =~ ^[A-Za-z0-9._-]+$ && "$1" != "." && "$1" != ".." ]]; }
valid_author() { local re='^[A-Za-z0-9._, -]+$'; [[ "$1" =~ $re ]]; }

# Returns 1 (and warns) if the file already exists, so we never overwrite work.
can_write() {
    if [ -e "$1" ]; then
        warn "$1 already exists, skipping."
        return 1
    fi
    return 0
}

# Option 1 or 2. $1 = label, $2 = default (1|2). Result in $ANSWER.
ask_option() {
    local reply
    while true; do
        read -r -p "$1 [1/2] (default $2): " reply
        reply="${reply:-$2}"
        case "$reply" in
            1|2) ANSWER="$reply"; return ;;
        esac
        err "Please enter 1 or 2."
    done
}

# Yes/no. $1 = question, $2 = default (y|n); the hint shows the default.
# Result in $ANSWER ("y" or "n").
ask_yn() {
    local reply hint="[Y/n]"
    [ "$2" = "n" ] && hint="[y/N]"
    while true; do
        read -r -p "$1 $hint: " reply
        reply="${reply:-$2}"
        case "$reply" in
            [Yy]|[Yy][Ee][Ss]) ANSWER="y"; return ;;
            [Nn]|[Nn][Oo])     ANSWER="n"; return ;;
        esac
        err "Please answer y or n."
    done
}

ask_name() {
    while true; do
        read -r -p "📁 Enter project/directory name: " DIR_NAME
        valid_name "$DIR_NAME" && return
        err "Use only letters, digits, '.', '_' or '-' (no spaces or slashes)."
    done
}

# ==============================================================================
# CONFIGURATION (genesis.conf, next to this script)
#
# The file is READ, never executed: no source, no eval. Only whitelisted keys
# are accepted and every value is validated before being stored.
# ==============================================================================

resolve_script_dir() {
    local src="${BASH_SOURCE[0]}" dir
    while [ -L "$src" ]; do
        dir="$(cd -P "$(dirname "$src")" && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$src")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
CONFIG_FILE="$SCRIPT_DIR/genesis.conf"

# Built-in defaults (used when the file or a key is missing/invalid)
CFG_AUTHOR=""
CFG_LANGUAGE="c"
CFG_TYPE="program"
CFG_HEADER="y"
CFG_MAKEFILE="y"
CFG_LIBFT="n"
CFG_README="y"

parse_bool() {
    case "$(lower "$1")" in
        y|yes) echo y ;;
        n|no)  echo n ;;
        *)     return 1 ;;
    esac
}

load_config() {
    local line key value v lineno=0
    [ -f "$CONFIG_FILE" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"
        line="$(trim "$line")"
        case "$line" in
            ""|"#"*) continue ;;
        esac
        if [[ "$line" != *=* ]]; then
            warn "genesis.conf:$lineno: not a KEY=VALUE line, ignored."
            continue
        fi
        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"

        case "$key" in
            AUTHOR)
                if [ -z "$value" ]; then
                    CFG_AUTHOR=""
                elif valid_author "$value"; then
                    CFG_AUTHOR="$value"
                else
                    warn "genesis.conf:$lineno: invalid AUTHOR (letters, digits, . _ , - and spaces only), ignored."
                fi ;;
            LANGUAGE)
                v="$(lower "$value")"
                case "$v" in
                    c|python) CFG_LANGUAGE="$v" ;;
                    *) warn "genesis.conf:$lineno: LANGUAGE must be c or python, ignored." ;;
                esac ;;
            PROJECT_TYPE)
                v="$(lower "$value")"
                case "$v" in
                    program|library) CFG_TYPE="$v" ;;
                    *) warn "genesis.conf:$lineno: PROJECT_TYPE must be program or library, ignored." ;;
                esac ;;
            GENERATE_HEADER|GENERATE_MAKEFILE|USE_LIBFT|GENERATE_README)
                if v="$(parse_bool "$value")"; then
                    case "$key" in
                        GENERATE_HEADER)   CFG_HEADER="$v" ;;
                        GENERATE_MAKEFILE) CFG_MAKEFILE="$v" ;;
                        USE_LIBFT)         CFG_LIBFT="$v" ;;
                        GENERATE_README)   CFG_README="$v" ;;
                    esac
                else
                    warn "genesis.conf:$lineno: $key must be y or n, ignored."
                fi ;;
            *)
                if [[ "$key" =~ ^[A-Za-z0-9_]+$ ]]; then
                    warn "genesis.conf:$lineno: unknown key '$key', ignored."
                else
                    warn "genesis.conf:$lineno: invalid line, ignored."
                fi ;;
        esac
    done < "$CONFIG_FILE"
}

# ==============================================================================
# SYNC: update SRCS in Makefile and file list in README.md
# ==============================================================================
sync_sources() {
    local raw block

    info "Scanning directory for .c files..."
    raw=$(find . -maxdepth 1 -name '*.c' | sed 's|^\./||' | sort | xargs -n 5)

    if [ -z "$raw" ]; then
        warn "No .c files found in the current directory."
        block="SRCS        ="
    else
        # First line: 'SRCS        = ...', the rest aligned; last line has no '\'
        block=$(printf '%s\n' "$raw" | awk '
            { lines[NR] = (NR == 1 ? "SRCS        = " : "              ") $0 }
            END { for (i = 1; i <= NR; i++) print lines[i] (i < NR ? " \\" : "") }
        ')
    fi

    # --- Makefile ---
    if [ ! -f Makefile ]; then
        warn "No Makefile found. Skipping Makefile update."
    elif ! grep -q '^# SRCS_START$' Makefile || ! grep -q '^# SRCS_END$' Makefile; then
        warn "Makefile has no '# SRCS_START' / '# SRCS_END' markers. Skipping."
    else
        BLOCK="$block" awk '
            /^# SRCS_END$/   { skip = 0 }
            !skip            { print }
            /^# SRCS_START$/ { skip = 1; print ENVIRON["BLOCK"] }
        ' Makefile > Makefile.tmp && mv Makefile.tmp Makefile
        ok "Makefile updated (5 files per line)."
    fi

    # --- README.md ---
    if [ ! -f README.md ]; then
        warn "No README.md found. Skipping README update."
    elif ! grep -q '^<!-- FILES_START -->$' README.md || ! grep -q '^<!-- FILES_END -->$' README.md; then
        warn "README.md has no <!-- FILES_START --> / <!-- FILES_END --> markers. Skipping."
    else
        LIST="$raw" awk '
            /^<!-- FILES_END -->$/   { skip = 0 }
            !skip                    { print }
            /^<!-- FILES_START -->$/ {
                skip = 1
                print "```c"
                if (ENVIRON["LIST"] != "") print ENVIRON["LIST"]
                print "```"
            }
        ' README.md > README.tmp && mv README.tmp README.md
        ok "README.md updated."
    fi
}

# ==============================================================================
# ARGUMENTS
# ==============================================================================
FAST=0
case "$1" in
    "")              ;;
    sync)            sync_sources; exit 0 ;;
    fast|default)    FAST=1 ;;
    -h|--help|help)  usage; exit 0 ;;
    *)               err "Unknown argument: $1"; usage; exit 1 ;;
esac

load_config
DEFAULT_AUTHOR="${CFG_AUTHOR:-${USER:-$(whoami)}}"

# Defaults translated to menu numbers
case "$CFG_LANGUAGE" in python) DEF_LANG=2 ;; *) DEF_LANG=1 ;; esac
case "$CFG_TYPE" in library) DEF_TYPE=2 ;; *) DEF_TYPE=1 ;; esac

# Variables filled by either branch below
DIR_NAME=""; REPO_TYPE="1"; GIT_URL=""; USERS=""; LANG_CHOICE="1"
NEED_HEADER="n"; NEED_MAKEFILE="n"; MK_TYPE="1"; USE_LIB="n"; NEED_README="y"

if [ "$FAST" = "0" ]; then
    # ==========================================================================
    # INTERACTIVE WIZARD (defaults come from genesis.conf)
    # ==========================================================================
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${CYAN}          🚀 GENESIS PROJECT INITIALIZER          ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""

    # Question 0: mode
    echo -e "${YELLOW}Select an action:${RESET}"
    echo "  1) Create / Scaffold a new project"
    echo "  2) Sync / Update .c files in current directory (Makefile & README)"
    ask_option "Option" 1

    if [ "$ANSWER" = "2" ]; then
        sync_sources
        exit 0
    fi

    # Question 1: project name
    echo ""
    ask_name

    # Question 2: local vs git clone
    echo ""
    echo -e "${YELLOW}Repository Setup:${RESET}"
    echo "  1) Local directory"
    echo "  2) Git clone (Vogsphere / GitHub)"
    ask_option "Option" 1
    REPO_TYPE="$ANSWER"

    if [ "$REPO_TYPE" = "2" ]; then
        while [ -z "$GIT_URL" ]; do
            read -r -p "🔗 Enter Git URL: " GIT_URL
        done
    fi

    # Question 3: authors
    echo ""
    while true; do
        read -r -p "👤 Enter author login(s) (default: $DEFAULT_AUTHOR): " USERS
        USERS="${USERS:-$DEFAULT_AUTHOR}"
        valid_author "$USERS" && break
        err "Use only letters, digits, '.', '_', ',', '-' and spaces."
    done

    # Question 4: language
    echo ""
    echo -e "${YELLOW}Select Project Language:${RESET}"
    echo "  1) C (Common Core / Piscine)"
    echo "  2) Python (Common Core)"
    ask_option "Option" "$DEF_LANG"
    LANG_CHOICE="$ANSWER"

    if [ "$LANG_CHOICE" = "1" ]; then
        echo ""
        ask_yn "📄 Generate $DIR_NAME.h?" "$CFG_HEADER"
        NEED_HEADER="$ANSWER"

        ask_yn "🛠️  Generate a Makefile?" "$CFG_MAKEFILE"
        NEED_MAKEFILE="$ANSWER"

        if [ "$NEED_MAKEFILE" = "y" ]; then
            echo ""
            echo -e "${YELLOW}Makefile target:${RESET}"
            echo "  1) Program (executable)"
            echo "  2) Static library (.a, built with ar)"
            ask_option "Option" "$DEF_TYPE"
            MK_TYPE="$ANSWER"

            ask_yn "📚 Link against your own libft (./libft)?" "$CFG_LIBFT"
            USE_LIB="$ANSWER"
        fi
    fi

    # Question 5: README
    echo ""
    ask_yn "📝 Generate README.md?" "$CFG_README"
    NEED_README="$ANSWER"

else
    # ==========================================================================
    # FAST MODE (everything comes from genesis.conf; only the name may be asked)
    # ==========================================================================
    if [ -f "$CONFIG_FILE" ]; then
        info "Fast mode: reading $CONFIG_FILE"
    else
        warn "No genesis.conf next to the script: using built-in defaults."
    fi

    DIR_NAME="${2:-}"
    GIT_URL="${3:-}"
    if [ -n "$DIR_NAME" ] && ! valid_name "$DIR_NAME"; then
        err "Invalid project name '$DIR_NAME'."
        DIR_NAME=""
    fi
    [ -z "$DIR_NAME" ] && ask_name

    [ -n "$GIT_URL" ] && REPO_TYPE="2"
    USERS="$DEFAULT_AUTHOR"
    LANG_CHOICE="$DEF_LANG"

    if [ "$LANG_CHOICE" = "1" ]; then
        NEED_HEADER="$CFG_HEADER"
        NEED_MAKEFILE="$CFG_MAKEFILE"
        if [ "$NEED_MAKEFILE" = "y" ]; then
            MK_TYPE="$DEF_TYPE"
            USE_LIB="$CFG_LIBFT"
        fi
    fi
    NEED_README="$CFG_README"

    if [ "$LANG_CHOICE" = "1" ]; then
        info "Settings: C, header=$NEED_HEADER, makefile=$NEED_MAKEFILE (type=$CFG_TYPE, libft=$USE_LIB), readme=$NEED_README, author=$USERS"
    else
        info "Settings: Python, readme=$NEED_README, author=$USERS"
    fi
fi

# ==============================================================================
# EXECUTION: scaffolding
# ==============================================================================
echo ""
info "Scaffolding project '$DIR_NAME'..."

if [ "$REPO_TYPE" = "2" ]; then
    git clone -- "$GIT_URL" "$DIR_NAME" || { err "Failed to clone repository."; exit 1; }
else
    if [ -d "$DIR_NAME" ]; then
        warn "Directory '$DIR_NAME' already exists: existing files will be kept."
    fi
    mkdir -p "$DIR_NAME"
fi

cd "$DIR_NAME" || exit 1

# Valid C identifier: uppercase, anything else -> '_', no leading digit
HEADER_GUARD="$(echo "$DIR_NAME" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9\n' '_')_H"
[[ "$HEADER_GUARD" =~ ^[0-9] ]] && HEADER_GUARD="_$HEADER_GUARD"

# ------------------------------------------------------------------------------
# C project
# ------------------------------------------------------------------------------
if [ "$LANG_CHOICE" = "1" ]; then

    if [ "$NEED_HEADER" = "y" ] && can_write "$DIR_NAME.h"; then
        info "Creating $DIR_NAME.h..."
        cat << EOF > "$DIR_NAME.h"
#ifndef $HEADER_GUARD
# define $HEADER_GUARD

# include <unistd.h>
# include <stdlib.h>

/* Code */

#endif
EOF
    fi

    HEADER_NAME=""
    [ -f "$DIR_NAME.h" ] && HEADER_NAME="$DIR_NAME.h"

    if [ "$NEED_MAKEFILE" = "y" ] && can_write Makefile; then
        info "Creating Makefile..."
        [ -z "$HEADER_NAME" ] && warn "No $DIR_NAME.h found: HEADER is left empty in the Makefile."

        if [ "$MK_TYPE" = "2" ]; then
            # Static library name: ft_printf -> libftprintf.a, libft -> libft.a
            LIB_NAME="$(lower "$DIR_NAME" | tr -d '._-')"
            case "$LIB_NAME" in
                lib*) ;;
                *)    LIB_NAME="lib$LIB_NAME" ;;
            esac
            LIB_NAME="$LIB_NAME.a"

            if [ "$USE_LIB" = "y" ]; then
                cat << EOF > Makefile
NAME        = $LIB_NAME

# SRCS_START
SRCS        =
# SRCS_END

OBJS        = \$(SRCS:.c=.o)

HEADER      = $HEADER_NAME

LIBFT_DIR   = ./libft
LIBFT       = \$(LIBFT_DIR)/libft.a
INCLUDES    = -I. -I\$(LIBFT_DIR)

CC          = cc
CFLAGS      = -Wall -Wextra -Werror
RM          = rm -f

all: \$(NAME)

\$(NAME): \$(LIBFT) \$(OBJS)
	cp \$(LIBFT) \$(NAME)
	ar rcs \$(NAME) \$(OBJS)

\$(LIBFT):
	\$(MAKE) -C \$(LIBFT_DIR)

%.o: %.c \$(HEADER)
	\$(CC) \$(CFLAGS) \$(INCLUDES) -c \$< -o \$@

clean:
	\$(RM) \$(OBJS)
	\$(MAKE) -C \$(LIBFT_DIR) clean

fclean: clean
	\$(RM) \$(NAME)
	\$(MAKE) -C \$(LIBFT_DIR) fclean

re: fclean all

.PHONY: all clean fclean re
EOF
            else
                cat << EOF > Makefile
NAME        = $LIB_NAME

# SRCS_START
SRCS        =
# SRCS_END

OBJS        = \$(SRCS:.c=.o)
HEADER      = $HEADER_NAME

CC          = cc
CFLAGS      = -Wall -Wextra -Werror -I.
RM          = rm -f

all: \$(NAME)

\$(NAME): \$(OBJS)
	ar rcs \$(NAME) \$(OBJS)

%.o: %.c \$(HEADER)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

clean:
	\$(RM) \$(OBJS)

fclean: clean
	\$(RM) \$(NAME)

re: fclean all

.PHONY: all clean fclean re
EOF
            fi

        elif [ "$USE_LIB" = "y" ]; then
            cat << EOF > Makefile
NAME        = $DIR_NAME

# SRCS_START
SRCS        =
# SRCS_END

OBJS        = \$(SRCS:.c=.o)

HEADER      = $HEADER_NAME

LIBFT_DIR   = ./libft
LIBFT       = \$(LIBFT_DIR)/libft.a
INCLUDES    = -I. -I\$(LIBFT_DIR)

CC          = cc
CFLAGS      = -Wall -Wextra -Werror
RM          = rm -f

all: \$(NAME)

\$(NAME): \$(LIBFT) \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -L\$(LIBFT_DIR) -lft -o \$(NAME)

\$(LIBFT):
	\$(MAKE) -C \$(LIBFT_DIR)

%.o: %.c \$(HEADER)
	\$(CC) \$(CFLAGS) \$(INCLUDES) -c \$< -o \$@

clean:
	\$(RM) \$(OBJS)
	\$(MAKE) -C \$(LIBFT_DIR) clean

fclean: clean
	\$(RM) \$(NAME)
	\$(MAKE) -C \$(LIBFT_DIR) fclean

re: fclean all

.PHONY: all clean fclean re
EOF
        else
            cat << EOF > Makefile
NAME        = $DIR_NAME

# SRCS_START
SRCS        =
# SRCS_END

OBJS        = \$(SRCS:.c=.o)
HEADER      = $HEADER_NAME

CC          = cc
CFLAGS      = -Wall -Wextra -Werror -I.
RM          = rm -f

all: \$(NAME)

\$(NAME): \$(OBJS)
	\$(CC) \$(CFLAGS) \$(OBJS) -o \$(NAME)

%.o: %.c \$(HEADER)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

clean:
	\$(RM) \$(OBJS)

fclean: clean
	\$(RM) \$(NAME)

re: fclean all

.PHONY: all clean fclean re
EOF
        fi
    fi

# ------------------------------------------------------------------------------
# Python project
# ------------------------------------------------------------------------------
else
    info "Setting up Python project structure..."

    if can_write main.py; then
        cat << EOF > main.py
#!/usr/bin/env python3
"""
Project: $DIR_NAME
Author(s): $USERS
"""


def main():
    print("Hello from $DIR_NAME!")


if __name__ == "__main__":
    main()
EOF
        chmod +x main.py
    fi
    [ -e requirements.txt ] || touch requirements.txt
fi

# ------------------------------------------------------------------------------
# README.md
# ------------------------------------------------------------------------------
if [ "$NEED_README" = "y" ] && can_write README.md; then
    info "Creating README.md..."

    # The file list (and its markers) only makes sense for C projects
    FILES_SECTION=""
    if [ "$LANG_CHOICE" = "1" ]; then
        FILES_SECTION="### Project Files

<!-- FILES_START -->
<!-- FILES_END -->
"
    fi

    cat << EOF > README.md
*This project has been created as part of the 42 curriculum by $USERS.*

# $DIR_NAME

## Description

<!-- Goal of the project, short overview and allowed external functions. -->

$FILES_SECTION
## Algorithm / Architecture: explanation and justification

<!--
- Data structures or classes used and why.
- Step-by-step flow, ideally with a worked example.
- Memory management / performance.
- Trade-offs and limitations.
-->

## Instructions

### Usage

<!-- How to run it, with a short example. -->

### Testing

<!-- Edge cases tested and tools used. -->

## Resources

- [Resource name](https://example.com) - what it was used for.

### Use of AI

<!-- Which AI tools were used, for which tasks and for which parts of the project. -->
EOF
fi

# Pick up any .c files that were already there (e.g. a cloned repository)
if [ "$LANG_CHOICE" = "1" ] && compgen -G "*.c" > /dev/null; then
    sync_sources
fi

echo ""
printf '%b✨ Workspace for %s successfully created for [%s]!%b\n' "$GREEN" "'$DIR_NAME'" "$USERS" "$RESET"
