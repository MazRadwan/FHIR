#!/bin/bash

# FHIR Integration Test Suite
# Tests end-to-end workflows and data integrity

set -e

# Configuration
FHIR_BASE_URL="http://localhost:8080/fhir"
TEST_RESULTS_DIR="tests/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$TEST_RESULTS_DIR/integration_test_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Helper functions
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

test_start() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "${YELLOW}[TEST $TOTAL_TESTS]${NC} $1"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log "${GREEN}✅ PASS${NC}: $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log "${RED}❌ FAIL${NC}: $1"
    if [[ "$2" != "continue" ]]; then
        exit 1
    fi
}

# Test 1: Full CRUD Workflow
test_full_crud_workflow() {
    test_start "Full CRUD Workflow (Patient + Observation)"
    
    # Step 1: Create Patient
    PATIENT_JSON='{
        "resourceType": "Patient",
        "name": [{"family": "Workflow", "given": ["Test"]}],
        "gender": "female",
        "birthDate": "1985-05-15",
        "active": true
    }'
    
    PATIENT_RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" \
        -H "Content-Type: application/fhir+json" \
        -d "$PATIENT_JSON")
    
    PATIENT_ID=$(echo "$PATIENT_RESPONSE" | jq -r '.id')
    
    if [[ "$PATIENT_ID" != "null" && -n "$PATIENT_ID" ]]; then
        test_pass "Patient created with ID: $PATIENT_ID"
    else
        test_fail "Failed to create patient"
        return 1
    fi
    
    # Step 2: Create multiple observations
    for i in {1..3}; do
        OBSERVATION_JSON="{
            \"resourceType\": \"Observation\",
            \"status\": \"final\",
            \"category\": [{
                \"coding\": [{
                    \"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\",
                    \"code\": \"vital-signs\",
                    \"display\": \"Vital Signs\"
                }]
            }],
            \"code\": {
                \"coding\": [{
                    \"system\": \"http://loinc.org\",
                    \"code\": \"8867-4\",
                    \"display\": \"Heart rate\"
                }]
            },
            \"subject\": {
                \"reference\": \"Patient/$PATIENT_ID\"
            },
            \"effectiveDateTime\": \"2025-07-16T$(printf '%02d' $((10 + i))):00:00+00:00\",
            \"valueQuantity\": {
                \"value\": $((70 + i)),
                \"unit\": \"beats/minute\",
                \"system\": \"http://unitsofmeasure.org\",
                \"code\": \"/min\"
            }
        }"
        
        OBSERVATION_RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Observation" \
            -H "Content-Type: application/fhir+json" \
            -d "$OBSERVATION_JSON")
        
        OBSERVATION_ID=$(echo "$OBSERVATION_RESPONSE" | jq -r '.id')
        
        if [[ "$OBSERVATION_ID" != "null" && -n "$OBSERVATION_ID" ]]; then
            test_pass "Observation $i created with ID: $OBSERVATION_ID"
        else
            test_fail "Failed to create observation $i"
            return 1
        fi
    done
    
    # Step 3: Search observations by patient
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?subject=Patient/$PATIENT_ID")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -eq 3 ]]; then
        test_pass "Found all 3 observations for patient"
    else
        test_fail "Expected 3 observations, found $SEARCH_TOTAL"
        return 1
    fi
    
    # Step 4: Verify data integrity
    FIRST_OBS_SUBJECT=$(echo "$SEARCH_RESPONSE" | jq -r '.entry[0].resource.subject.reference')
    if [[ "$FIRST_OBS_SUBJECT" == "Patient/$PATIENT_ID" ]]; then
        test_pass "Data integrity verified - observations reference correct patient"
    else
        test_fail "Data integrity issue - observation references wrong patient"
    fi
}

# Test 2: Concurrent Operations
test_concurrent_operations() {
    test_start "Concurrent Operations"
    
    # Create base patient
    PATIENT_JSON='{"resourceType": "Patient", "name": [{"family": "Concurrent", "given": ["Test"]}], "active": true}'
    PATIENT_RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" -H "Content-Type: application/fhir+json" -d "$PATIENT_JSON")
    PATIENT_ID=$(echo "$PATIENT_RESPONSE" | jq -r '.id')
    
    # Create multiple observations concurrently
    for i in {1..5}; do
        (
            OBSERVATION_JSON="{
                \"resourceType\": \"Observation\",
                \"status\": \"final\",
                \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"vital-signs\"}]}],
                \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"8867-4\", \"display\": \"Heart rate\"}]},
                \"subject\": {\"reference\": \"Patient/$PATIENT_ID\"},
                \"effectiveDateTime\": \"2025-07-16T10:0$i:00+00:00\",
                \"valueQuantity\": {\"value\": $((60 + i)), \"unit\": \"beats/minute\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"/min\"}
            }"
            
            curl -s -X POST "$FHIR_BASE_URL/Observation" \
                -H "Content-Type: application/fhir+json" \
                -d "$OBSERVATION_JSON" > /dev/null
        ) &
    done
    
    # Wait for all background processes
    wait
    
    # Check if all observations were created
    sleep 2  # Allow time for indexing
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?subject=Patient/$PATIENT_ID")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -eq 5 ]]; then
        test_pass "All 5 concurrent observations created successfully"
    else
        test_fail "Expected 5 observations from concurrent operations, found $SEARCH_TOTAL"
    fi
}

# Test 3: Performance under load
test_performance_load() {
    test_start "Performance Under Load"
    
    START_TIME=$(date +%s)
    
    # Create patient
    PATIENT_JSON='{"resourceType": "Patient", "name": [{"family": "Performance", "given": ["Test"]}], "active": true}'
    PATIENT_RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" -H "Content-Type: application/fhir+json" -d "$PATIENT_JSON")
    PATIENT_ID=$(echo "$PATIENT_RESPONSE" | jq -r '.id')
    
    # Create 20 observations rapidly
    for i in {1..20}; do
        OBSERVATION_JSON="{
            \"resourceType\": \"Observation\",
            \"status\": \"final\",
            \"category\": [{\"coding\": [{\"system\": \"http://terminology.hl7.org/CodeSystem/observation-category\", \"code\": \"vital-signs\"}]}],
            \"code\": {\"coding\": [{\"system\": \"http://loinc.org\", \"code\": \"8867-4\", \"display\": \"Heart rate\"}]},
            \"subject\": {\"reference\": \"Patient/$PATIENT_ID\"},
            \"effectiveDateTime\": \"2025-07-16T$(printf '%02d' $((10 + i/10))):$(printf '%02d' $((i % 60))):00+00:00\",
            \"valueQuantity\": {\"value\": $((60 + i)), \"unit\": \"beats/minute\", \"system\": \"http://unitsofmeasure.org\", \"code\": \"/min\"}
        }"
        
        curl -s -X POST "$FHIR_BASE_URL/Observation" \
            -H "Content-Type: application/fhir+json" \
            -d "$OBSERVATION_JSON" > /dev/null
    done
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Verify all observations were created
    sleep 2
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Observation?subject=Patient/$PATIENT_ID")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -eq 20 ]]; then
        test_pass "Created 20 observations in ${DURATION}s (avg: $(echo "scale=2; $DURATION/20" | bc)s per operation)"
    else
        test_fail "Expected 20 observations, found $SEARCH_TOTAL after ${DURATION}s"
    fi
    
    # Performance benchmark
    if [[ "$DURATION" -lt 30 ]]; then
        test_pass "Performance acceptable: ${DURATION}s for 20 operations"
    else
        test_fail "Performance issue: ${DURATION}s for 20 operations (>30s threshold)"
    fi
}

# Test 4: Resource Validation
test_resource_validation() {
    test_start "FHIR Resource Validation"
    
    # Test valid patient
    VALID_PATIENT='{"resourceType": "Patient", "name": [{"family": "Valid"}], "active": true}'
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" -H "Content-Type: application/fhir+json" -d "$VALID_PATIENT" -w "HTTPSTATUS:%{http_code}")
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    if [[ "$HTTP_CODE" == "201" ]]; then
        test_pass "Valid patient accepted"
    else
        test_fail "Valid patient rejected with HTTP $HTTP_CODE"
    fi
    
    # Test invalid resource type
    INVALID_RESOURCE='{"resourceType": "InvalidResource", "name": [{"family": "Invalid"}]}'
    RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" -H "Content-Type: application/fhir+json" -d "$INVALID_RESOURCE" -w "HTTPSTATUS:%{http_code}")
    HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    if [[ "$HTTP_CODE" =~ ^4[0-9][0-9]$ ]]; then
        test_pass "Invalid resource type rejected with HTTP $HTTP_CODE"
    else
        test_fail "Invalid resource type should be rejected, got HTTP $HTTP_CODE"
    fi
}

# Test 5: Search Functionality
test_search_functionality() {
    test_start "Advanced Search Functionality"
    
    # Create test data
    PATIENT_JSON='{"resourceType": "Patient", "name": [{"family": "SearchTest", "given": ["Advanced"]}], "gender": "male", "active": true}'
    PATIENT_RESPONSE=$(curl -s -X POST "$FHIR_BASE_URL/Patient" -H "Content-Type: application/fhir+json" -d "$PATIENT_JSON")
    PATIENT_ID=$(echo "$PATIENT_RESPONSE" | jq -r '.id')
    
    # Test search by name
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Patient?name=SearchTest")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -gt 0 ]]; then
        test_pass "Search by name successful: found $SEARCH_TOTAL patient(s)"
    else
        test_fail "Search by name failed: found $SEARCH_TOTAL patients"
    fi
    
    # Test search by gender
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Patient?gender=male")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -gt 0 ]]; then
        test_pass "Search by gender successful: found $SEARCH_TOTAL patient(s)"
    else
        test_fail "Search by gender failed: found $SEARCH_TOTAL patients"
    fi
    
    # Test search with no results
    SEARCH_RESPONSE=$(curl -s "$FHIR_BASE_URL/Patient?name=NonExistentPatient")
    SEARCH_TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total')
    
    if [[ "$SEARCH_TOTAL" -eq 0 ]]; then
        test_pass "Search with no results handled correctly"
    else
        test_fail "Search should return 0 results, found $SEARCH_TOTAL"
    fi
}

# Setup and cleanup
setup_tests() {
    log "${YELLOW}Setting up integration tests...${NC}"
    mkdir -p "$TEST_RESULTS_DIR"
    
    if ! curl -s -f "$FHIR_BASE_URL/metadata" > /dev/null; then
        test_fail "FHIR server not available at $FHIR_BASE_URL"
    fi
    
    # Check if required tools are available
    if ! command -v jq &> /dev/null; then
        test_fail "jq is required but not installed"
    fi
    
    if ! command -v bc &> /dev/null; then
        test_fail "bc is required but not installed"
    fi
    
    log "${GREEN}✅ Setup complete${NC}"
}

# Main execution
main() {
    log "${YELLOW}============================================${NC}"
    log "${YELLOW}    FHIR Integration Test Suite            ${NC}"
    log "${YELLOW}============================================${NC}"
    log "Start time: $(date)"
    log "FHIR Base URL: $FHIR_BASE_URL"
    log "Log file: $LOG_FILE"
    log ""
    
    setup_tests
    
    test_full_crud_workflow
    test_concurrent_operations
    test_performance_load
    test_resource_validation
    test_search_functionality
    
    log ""
    log "${YELLOW}============================================${NC}"
    log "${YELLOW}              TEST SUMMARY                 ${NC}"
    log "${YELLOW}============================================${NC}"
    log "Total tests: $TOTAL_TESTS"
    log "Passed: ${GREEN}$TESTS_PASSED${NC}"
    log "Failed: ${RED}$TESTS_FAILED${NC}"
    log "End time: $(date)"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "${GREEN}🎉 ALL INTEGRATION TESTS PASSED!${NC}"
        exit 0
    else
        log "${RED}💥 $TESTS_FAILED INTEGRATION TEST(S) FAILED!${NC}"
        exit 1
    fi
}

main "$@"