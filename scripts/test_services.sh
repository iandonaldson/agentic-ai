#!/usr/bin/env bash
# Service Integration Test Script
# Tests that all services are working together correctly

set -uo pipefail  # Removed -e so script continues on individual test failures

echo "🔧 Agentic AI Service Integration Tests"
echo "======================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
BASE_URL="http://localhost:8000"
TEST_TIMEOUT=30
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run HTTP test
http_test() {
    local test_name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="$4"
    local data="${5:-}"

    echo -e "${BLUE}Testing:${NC} $test_name"

    # Build curl command
    local curl_cmd="curl -s -w '%{http_code}' -o /tmp/response.json --max-time $TEST_TIMEOUT"

    if [ "$method" = "POST" ]; then
        curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json'"
        if [ -n "$data" ]; then
            curl_cmd="$curl_cmd -d '$data'"
        fi
    fi

    curl_cmd="$curl_cmd '$BASE_URL$endpoint'"

    # Execute request
    local status_code
    if status_code=$(eval "$curl_cmd" 2>/dev/null); then
        if [ "$status_code" = "$expected_status" ]; then
            echo -e "  ${GREEN}✅ PASS${NC} - HTTP $status_code"
            if [ -f /tmp/response.json ]; then
                local response_size=$(wc -c < /tmp/response.json)
                echo -e "     Response: ${response_size} bytes"
                # Show first 100 chars of response for debugging
                if [ $response_size -lt 200 ]; then
                    echo -e "     Content: $(cat /tmp/response.json)"
                fi
            fi
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ FAIL${NC} - Expected HTTP $expected_status, got $status_code"
            if [ -f /tmp/response.json ]; then
                echo -e "     Response: $(cat /tmp/response.json)"
            fi
            ((TESTS_FAILED++))
        fi
    else
        echo -e "  ${RED}❌ FAIL${NC} - Request failed (connection error)"
        ((TESTS_FAILED++))
    fi
    echo
}

# Function to check service is running
check_service() {
    local service_name="$1"
    local check_command="$2"

    echo -e "${BLUE}Checking:${NC} $service_name"
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ RUNNING${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}❌ NOT RUNNING${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to wait for service
wait_for_service() {
    local service_name="$1"
    local check_url="$2"
    local max_attempts=10
    local attempt=1

    echo -e "${BLUE}Waiting for:${NC} $service_name"

    while [ $attempt -le $max_attempts ]; do
        if curl -s --max-time 5 "$check_url" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ READY${NC} (attempt $attempt/$max_attempts)"
            return 0
        fi
        echo -e "  ${YELLOW}⏳ WAITING${NC} (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    echo -e "  ${RED}❌ TIMEOUT${NC} - Service not ready after $max_attempts attempts"
    return 1
}

echo "1. SERVICE STATUS CHECK"
echo "======================"
check_service "PostgreSQL" "pg_isready -h 127.0.0.1 -p 5432"
check_service "Web Service" "pgrep -f 'uvicorn.*main:app'"

echo "2. SERVICE CONNECTIVITY"
echo "======================"
wait_for_service "FastAPI Web Service" "$BASE_URL/healthz"

echo "3. BASIC ENDPOINT TESTS"
echo "======================"
http_test "Health Check" "GET" "/healthz" "200"
http_test "Root Endpoint" "GET" "/" "200"
http_test "API Documentation" "GET" "/docs" "200"
http_test "OpenAPI Schema" "GET" "/openapi.json" "200"

echo "4. FUNCTIONAL ENDPOINT TESTS"
echo "============================"
http_test "Simple Addition" "GET" "/add?a=5&b=3" "200"

# Test report generation (if API keys are available)
if [ -n "${OPENAI_API_KEY:-}" ] && [ -n "${TAVILY_API_KEY:-}" ]; then
    echo -e "${BLUE}API keys detected - testing report generation${NC}"

    # Start a report generation
    local test_data='{"prompt": "Test prompt for validation", "model": "openai:gpt-4o"}'
    echo -e "${BLUE}Testing:${NC} Report Generation (Start)"

    local task_response
    if task_response=$(curl -s -X POST -H "Content-Type: application/json" \
                      -d "$test_data" "$BASE_URL/generate_report" 2>/dev/null); then

        # Extract task ID
        local task_id
        if task_id=$(echo "$task_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['task_id'])" 2>/dev/null); then
            echo -e "  ${GREEN}✅ PASS${NC} - Task created: $task_id"
            ((TESTS_PASSED++))

            # Test progress endpoint
            http_test "Task Progress Check" "GET" "/task_progress/$task_id" "200"
            http_test "Task Status Check" "GET" "/task_status/$task_id" "200"
        else
            echo -e "  ${RED}❌ FAIL${NC} - Invalid response format"
            echo -e "     Response: $task_response"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "  ${RED}❌ FAIL${NC} - Report generation request failed"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIPPED${NC} - API keys not configured (OPENAI_API_KEY, TAVILY_API_KEY)"
    echo "   Report generation tests require valid API keys in .env file"
fi

echo

echo "5. ERROR HANDLING TESTS"
echo "======================"
http_test "Invalid Endpoint" "GET" "/nonexistent" "404"
http_test "Invalid Method" "PUT" "/healthz" "405"

echo "6. FINAL SUMMARY"
echo "================"
echo -e "${GREEN}Tests Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Tests Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}Total Tests:${NC} $((TESTS_PASSED + TESTS_FAILED))"

# Cleanup
rm -f /tmp/response.json

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL INTEGRATION TESTS PASSED!${NC}"
    echo "All services are working correctly together."
    exit 0
else
    echo -e "\n${RED}⚠️  SOME INTEGRATION TESTS FAILED!${NC}"
    echo "Please review the failed tests above and check service configuration."
    exit 1
fi
