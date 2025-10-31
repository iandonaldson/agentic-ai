#!/usr/bin/env bash
# Docker Environment Validation Script
# Tests Docker-related functionality when Docker is available

set -euo pipefail

echo "🐳 Docker Environment Validation"
echo "================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -e "${BLUE}Testing:${NC} $test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

# Check if Docker is available
echo "1. DOCKER AVAILABILITY"
echo "======================"
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker not available in this environment${NC}"
    echo "This is expected in GitHub Codespaces as we're already inside a container."
    echo "Docker validation can only be run in environments with Docker daemon access."
    echo
    echo "To test Docker functionality:"
    echo "1. Clone this repository to a local machine with Docker"
    echo "2. Run this script: ./scripts/validate_docker.sh"
    echo "3. Or use the Makefile: make docker-build, make docker-dev, make docker-prod"
    exit 0
fi

echo -e "${GREEN}✅ Docker is available${NC}"
echo "Docker version: $(docker --version)"
echo

# Test Docker commands
echo "2. DOCKER FILE VALIDATION"
echo "========================="
run_test "Dockerfile exists" "test -f Dockerfile"
run_test "docker-compose.yml exists" "test -f docker-compose.yml"
run_test ".dockerignore exists" "test -f .dockerignore"
run_test "Source requirements.in exists" "test -f .devcontainer/requirements.in"
run_test "Source requirements-dev.in exists" "test -f .devcontainer/requirements-dev.in"

echo "3. DOCKER BUILD TESTS"
echo "===================="
run_test "Build development image" "docker build --target development -t agentic-ai:dev-test ."
run_test "Build production image" "docker build --target production -t agentic-ai:prod-test ."

echo "4. DOCKER COMPOSE VALIDATION"
echo "============================"
run_test "Validate docker-compose.yml" "docker-compose config"
run_test "Check development profile" "docker-compose --profile dev config"
run_test "Check production profile" "docker-compose --profile prod config"

echo "5. IMAGE INSPECTION"
echo "=================="
if docker image inspect agentic-ai:dev-test >/dev/null 2>&1; then
    echo -e "${BLUE}Development Image Details:${NC}"
    echo "  Size: $(docker images agentic-ai:dev-test --format 'table {{.Size}}' | tail -1)"
    echo "  Created: $(docker images agentic-ai:dev-test --format 'table {{.CreatedSince}}' | tail -1)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Development image not found${NC}"
    ((TESTS_FAILED++))
fi

if docker image inspect agentic-ai:prod-test >/dev/null 2>&1; then
    echo -e "${BLUE}Production Image Details:${NC}"
    echo "  Size: $(docker images agentic-ai:prod-test --format 'table {{.Size}}' | tail -1)"
    echo "  Created: $(docker images agentic-ai:prod-test --format 'table {{.CreatedSince}}' | tail -1)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Production image not found${NC}"
    ((TESTS_FAILED++))
fi
echo

echo "6. MAKEFILE DOCKER TARGETS"
echo "=========================="
run_test "make docker-build (dry run)" "make -n docker-build"
run_test "make docker-dev (dry run)" "make -n docker-dev"
run_test "make docker-prod (dry run)" "make -n docker-prod"
run_test "make docker-clean (dry run)" "make -n docker-clean"

echo "7. QUICK CONTAINER TEST"
echo "======================"
echo -e "${BLUE}Testing:${NC} Development container startup"
if timeout 30 docker run --rm -e DATABASE_URL=sqlite:///test.db agentic-ai:dev-test python -c "import main; print('✅ Import successful')" 2>/dev/null; then
    echo -e "  ${GREEN}✅ PASS${NC} - Development container runs correctly"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}❌ FAIL${NC} - Development container failed to start or import failed"
    ((TESTS_FAILED++))
fi

echo -e "${BLUE}Testing:${NC} Production container startup"
if timeout 15 docker run --rm -e DATABASE_URL=sqlite:///test.db agentic-ai:prod-test python -c "import main; print('✅ Import successful')" 2>/dev/null; then
    echo -e "  ${GREEN}✅ PASS${NC} - Production container runs correctly"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}❌ FAIL${NC} - Production container failed to start or import failed"
    ((TESTS_FAILED++))
fi
echo

echo "8. CLEANUP"
echo "=========="
echo -e "${BLUE}Cleaning up test images...${NC}"
docker rmi agentic-ai:dev-test agentic-ai:prod-test >/dev/null 2>&1 || true
echo -e "${GREEN}✅ Cleanup completed${NC}"
echo

echo "9. FINAL SUMMARY"
echo "================"
echo -e "${GREEN}Tests Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Tests Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}Total Tests:${NC} $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL DOCKER TESTS PASSED!${NC}"
    echo "Docker configuration is working correctly."
    exit 0
else
    echo -e "\n${RED}⚠️  SOME DOCKER TESTS FAILED!${NC}"
    echo "Please review the failed tests above and fix Docker configuration issues."
    exit 1
fi
