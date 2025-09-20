#!/bin/bash
set -eo pipefail  # Changed from -euo to -eo to be less strict

usage() {
  echo "Usage: ./organize.sh <submissions_dir> <targets_dir> <tests_dir> <answers_dir> [-noexecute]"
  echo "Example: ./organize.sh submissions targets tests answers"
  exit 1
}

# absolute path helper 
abspath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$1"
  else
    ( cd "$(dirname "$1")" 2>/dev/null && printf "%s/%s\n" "$(pwd)" "$(basename "$1")" )
  fi
}

# args
if [[ $# -lt 4 || $# -gt 5 ]]; then
    usage
fi

SUB_DIR=$1
TARGET_DIR=$2
TEST_DIR=$3
ANS_DIR=$4
NOEXEC=${5:-""}

[[ -d "$SUB_DIR" ]] || { echo "submissions not found: $SUB_DIR"; exit 1; }
[[ -d "$TEST_DIR" ]] || { echo "tests not found: $TEST_DIR"; exit 1; }
[[ -d "$ANS_DIR"  ]] || { echo "answers not found: $ANS_DIR"; exit 1; }
[[ -z "$NOEXEC" || "$NOEXEC" == "-noexecute" ]] || usage

# normalize to absolute paths
SUB_DIR=$(abspath "$SUB_DIR")
TARGET_DIR=$(abspath "$TARGET_DIR")
TEST_DIR=$(abspath "$TEST_DIR")
ANS_DIR=$(abspath "$ANS_DIR")

# create target directories
mkdir -p "$TARGET_DIR"/{C,Python,Java}

extract_id() { 
    echo "$1" | grep -oE '[0-9]{9}' | tail -n1
}

find_code_file() {
    local root="$1"
    find "$root" -type f \( -name '*.c' -o -name '*.py' -o -name '*.java' \) 2>/dev/null | head -1
}

# Task A: Organize submissions into targets/C|Python|Java/<studentID>

echo "Task A: Organize"

# Process each folder in submissions directory
for sub_folder in "$SUB_DIR"/*; do
    if [[ ! -d "$sub_folder" ]]; then
        continue
    fi

    base="$(basename "$sub_folder")"
    sid="$(extract_id "$base")"

    if [[ -z "$sid" ]]; then
        echo "[SKIP] $base -> no 9-digit student ID found"
        continue
    fi

    # Find code file in the submission folder
    code="$(find_code_file "$sub_folder")"
    if [[ -z "$code" ]]; then
        echo "[SKIP] $sid -> no code file (.c/.py/.java) found"
        continue
    fi

    # Determine language and destination filename
    case "${code##*.}" in
        c)    lang="C";      dest="main.c"   ;;
        py)   lang="Python"; dest="main.py"  ;;
        java) lang="Java";   dest="Main.java";;
        *)    echo "[SKIP] $sid -> file isn't supported: $code"; continue ;;
    esac

    # Create student directory and copy file
    stud="$TARGET_DIR/$lang/$sid"
    mkdir -p "$stud"
    cp "$code" "$stud/$dest"
    echo "Organized: $sid  ($lang) -> $lang/$sid/$dest"
done

if [[ "${NOEXEC:-}" == "-noexecute" ]]; then
    echo "Task A complete (noexecute set; skipping Task B)"
    exit 0
fi

# Task B: Run everything inside targets/*/* and compare

echo "=== Task B: Execute & Match ==="

# gather test files (sorted numerically)
TESTS=()
for test_file in "$TEST_DIR"/test*.txt; do
    if [[ -f "$test_file" ]]; then
        TESTS+=("$test_file")
    fi
done

# Sort the tests array
IFS=$'\n' TESTS=($(sort -V <<< "${TESTS[*]}"))
unset IFS

if [[ ${#TESTS[@]} -eq 0 ]]; then
    echo "No test*.txt files found in $TEST_DIR"
    exit 1
fi

echo "Found ${#TESTS[@]} test file(s)."
for test in "${TESTS[@]}"; do
    echo "  - $(basename "$test")"
done

CSV="$TARGET_DIR/result.csv"
echo "student_id,type,matched,not_matched" > "$CSV"

# Process each language directory
for lang in C Python Java; do
    lang_dir="$TARGET_DIR/$lang"
    if [[ ! -d "$lang_dir" ]]; then
        echo "No $lang directory found, skipping."
        continue
    fi

    echo "Processing $lang students."

    # Process each student in this language
    for stud_dir in "$lang_dir"/*; do
        if [[ ! -d "$stud_dir" ]]; then
            continue
        fi

        sid="$(basename "$stud_dir")"
        echo ""
        echo "Student: $sid  Language: $lang"

        # Store current directory
        original_dir=$(pwd)

        # Change to student directory
        cd "$stud_dir" || {
            echo "Can't change to directory: $stud_dir"
            continue
        }

        # Compile as required
        compile_success=true
        case "$lang" in
            C)
                echo "Compiling C code: gcc main.c -o main.out"
                if gcc main.c -o main.out 2>build.err; then
                    echo "OK: main.out created"
                else
                    echo "FAIL: compilation error"
                    if [[ -f build.err ]]; then
                        echo "Build errors:"
                        cat build.err
                    fi
                    compile_success=false
                fi
                ;;
            Java)
                echo "Compiling Java code: javac Main.java"
                if javac Main.java 2>build.err; then
                    echo "OK: Main.class created"
                else
                    echo "FAIL: compilation error"
                    if [[ -f build.err ]]; then
                        echo "Build errors:"
                        cat build.err
                    fi
                    compile_success=false
                fi
                ;;
            Python)
                echo "Python script - no compilation needed"
                if [[ -f "main.py" ]]; then
                    compile_success=true
                else
                    echo "FAIL: main.py not found"
                    compile_success=false
                fi
                ;;
        esac

        matched=0
        notmatched=0

        # Run each test case
        for i in "${!TESTS[@]}"; do
            test_num=$((i + 1))
            test_file="${TESTS[i]}"
            out_file="out${test_num}.txt"
            ans_file="$ANS_DIR/ans${test_num}.txt"

            echo "Running test${test_num} with input: $(basename "$test_file")"

            # Initialize output file
            > "$out_file"

            # Execute based on language
            if [[ "$compile_success" == true ]]; then
                case "$lang" in
                    C)
                        if [[ -x "./main.out" ]]; then
                            echo "./main.out < $test_file > $out_file"
                            timeout 30s ./main.out < "$test_file" > "$out_file" 2>&1 || {
                                echo "Program execution failed or timed out" > "$out_file"
                            }
                        else
                            echo "Executable not found" > "$out_file"
                        fi
                        ;;
                    Java)
                        if [[ -f "Main.class" ]]; then
                            echo "java Main < $test_file > $out_file"
                            timeout 30s java Main < "$test_file" > "$out_file" 2>&1 || {
                                echo "Program execution failed or timed out" > "$out_file"
                            }
                        else
                            echo "Java class file not found" > "$out_file"
                        fi
                        ;;
                    Python)
                        if [[ -f "main.py" ]]; then
                            echo "python3 main.py < $test_file > $out_file"
                            timeout 30s python3 main.py < "$test_file" > "$out_file" 2>&1 || {
                                echo "Program execution failed or timed out" > "$out_file"
                            }
                        else
                            echo "Python file not found" > "$out_file"
                        fi
                        ;;
                esac
            else
                echo "Compilation failed - cannot execute" > "$out_file"
            fi

            # Compare with answer file
            if [[ -f "$ans_file" ]]; then
                if diff -q "$out_file" "$ans_file" >/dev/null 2>&1; then
                    echo "test${test_num}: MATCH ✓"
                    matched=$((matched + 1))
                else
                    echo "test${test_num}: NOT MATCH ✗"
                    notmatched=$((notmatched + 1))
                    echo "Expected output (first 3 lines):"
                    head -3 "$ans_file" 2>/dev/null | sed 's/^/  > /'
                    echo "Actual output (first 3 lines):"
                    head -3 "$out_file" 2>/dev/null | sed 's/^/  < /'
                fi
            else
                echo "test${test_num}: Answer file not found ($ans_file)"
                notmatched=$((notmatched + 1))
            fi

            echo "  -> Output saved to: $out_file"
        done

        # Return to original directory
        cd "$original_dir"

        # Write to CSV
        echo "${sid},${lang},${matched},${notmatched}" >> "$CSV"
        echo "$sid ($lang): matched=${matched}, not_matched=${notmatched}"
    done
done

echo ""
echo "Final Results
echo "CSV written to: $CSV"
echo ""
echo "CSV Contents:"
if [[ -f "$CSV" ]]; then
    cat "$CSV"
else
    echo "CSV file not created!"
fi

echo ""
echo "Task completed""