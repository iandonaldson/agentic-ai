#!/usr/bin/env bash
# Environment Validation Script for Agentic AI
# Tests that the development environment is properly configured

set -uo pipefail  # Removed -e so script continues on individual test failures

echo "🔍 Agentic AI Environment Validation"
echo "=================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    echo -e "${BLUE}Testing:${NC} $test_name"

    local actual_exit_code=0
    eval "$test_command" >/dev/null 2>&1 || actual_exit_code=$?

    if [ $actual_exit_code -eq $expected_exit_code ]; then
        echo -e "  ${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ FAIL${NC} (exit code: $actual_exit_code, expected: $expected_exit_code)"
        ((TESTS_FAILED++))
    fi
    echo
}

# Function to check if command exists
check_command() {
    local cmd="$1"
    local description="$2"

    echo -e "${BLUE}Checking:${NC} $description"
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=""
        case "$cmd" in
            python) version=$(python --version 2>&1 || echo "unknown") ;;
            pip) version=$(pip --version 2>&1 | head -1 || echo "unknown") ;;
            make) version=$(make --version 2>&1 | head -1 || echo "unknown") ;;
            psql) version=$(psql --version 2>&1 || echo "unknown") ;;
            *) version="Available" ;;
        esac
        echo -e "  ${GREEN}✅ FOUND${NC} - $version"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ MISSING${NC} - $cmd not found"
        ((TESTS_FAILED++))
    fi
    echo
}

# Function to check file exists
check_file() {
    local filepath="$1"
    local description="$2"

    echo -e "${BLUE}Checking:${NC} $description"
    if [ -f "$filepath" ]; then
        echo -e "  ${GREEN}✅ EXISTS${NC} - $filepath"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ MISSING${NC} - $filepath"
        ((TESTS_FAILED++))
    fi
    echo
}

# Function to check environment variable
check_env_var() {
    local var_name="$1"
    local description="$2"
    local required="${3:-false}"

    echo -e "${BLUE}Checking:${NC} $description"

    # Use indirect variable expansion safely
    local var_value=""
    if [[ -n "${!var_name+x}" ]]; then
        var_value="${!var_name}"
    fi

    if [ -n "$var_value" ]; then
        echo -e "  ${GREEN}✅ SET${NC} - $var_name"
        ((TESTS_PASSED++))
    else
        if [ "$required" = "true" ]; then
            echo -e "  ${RED}❌ MISSING${NC} - $var_name (required)"
            ((TESTS_FAILED++))
        else
            echo -e "  ${YELLOW}⚠️  NOT SET${NC} - $var_name (optional)"
        fi
    fi
    echo
}

echo "1. SYSTEM DEPENDENCIES"
echo "======================"
check_command "python" "Python interpreter"
check_command "pip" "Python package manager"
check_command "make" "Make build tool"
check_command "psql" "PostgreSQL client"
check_command "git" "Git version control"

echo "2. PYTHON ENVIRONMENT"
echo "===================="
echo -e "${BLUE}Python Location:${NC} $(which python)"
echo -e "${BLUE}Python Version:${NC} $(python --version)"
echo -e "${BLUE}Virtual Environment:${NC}"
current_python=$(which python)
if [[ "$current_python" == *"/opt/venv"* ]]; then
    echo -e "  ${GREEN}✅ ACTIVE${NC} - Using /opt/venv"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}❌ INCORRECT${NC} - Expected /opt/venv, got $current_python"
    ((TESTS_FAILED++))
fi
echo

echo "3. PROJECT FILES"
echo "==============="
check_file "main.py" "Main application file"
check_file "requirements.txt" "Production requirements"
check_file "requirements-dev.txt" "Development requirements"
check_file "pyproject.toml" "Project configuration"
check_file "Makefile" "Build configuration"
check_file "Dockerfile" "Docker configuration"
check_file "docker-compose.yml" "Docker Compose configuration"
check_file ".env" "Environment configuration"

echo "4. ENVIRONMENT VARIABLES"
echo "========================"
check_env_var "DATABASE_URL" "Database connection string" false
check_env_var "OPENAI_API_KEY" "OpenAI API key" false
check_env_var "TAVILY_API_KEY" "Tavily API key" false

echo "5. MAKEFILE TARGETS"
echo "=================="
run_test "make help" "make help"
run_test "make dependencies (dry run)" "make -n dependencies"
run_test "make test (dry run)" "make -n test"
run_test "make lint (dry run)" "make -n lint"

echo "6. SERVICE STATUS"
echo "================"
echo -e "${BLUE}Checking:${NC} Service status"
if make status >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ SERVICES${NC} - Status check successful"
    ((TESTS_PASSED++))

    # Show actual status
    echo -e "${BLUE}Current Status:${NC}"
    make status | sed 's/^/  /'
else
    echo -e "  ${RED}❌ SERVICES${NC} - Status check failed"
    ((TESTS_FAILED++))
fi
echo

echo "7. PYTHON PACKAGES"
echo "=================="
echo -e "${BLUE}Checking:${NC} Required Python packages"
# Package name -> import name mapping
declare -A packages=(
    ["fastapi"]="fastapi"
    ["uvicorn"]="uvicorn"
    ["sqlalchemy"]="sqlalchemy"
    ["psycopg2-binary"]="psycopg2"
    ["python-dotenv"]="dotenv"
)

for package_name in "${!packages[@]}"; do
    import_name="${packages[$package_name]}"
    if python -c "import $import_name" 2>/dev/null; then
        version=$(python -c "import $import_name; print(getattr($import_name, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✅ $package_name${NC} - $version"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ $package_name${NC} - Not installed or importable"
        ((TESTS_FAILED++))
    fi
done
echo

echo "8. FINAL SUMMARY"
echo "================"
echo -e "${GREEN}Tests Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Tests Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}Total Tests:${NC} $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo "Environment is properly configured for development."
    exit 0
else
    echo -e "\n${RED}⚠️  SOME TESTS FAILED!${NC}"
    echo "Please review the failed tests above and fix any issues."
    exit 1
fi
