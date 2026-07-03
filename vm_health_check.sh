#!/bin/bash

################################################################################
# VM Health Check Script
# 
# Purpose: Analyze the health status of an Ubuntu virtual machine based on:
#          - CPU utilization
#          - Memory utilization
#          - Disk space utilization
#
# Usage: ./vm_health_check.sh [explain]
# 
# Arguments:
#   explain (optional) - Display detailed explanation for health status
#
# Health Status Rules:
#   - HEALTHY: All metrics (CPU, Memory, Disk) are below 60% utilization
#   - NOT HEALTHY: Any metric exceeds 60% utilization
#
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables to store metrics
CPU_USAGE=0
MEMORY_USAGE=0
DISK_USAGE=0
THRESHOLD=60
EXPLAIN_FLAG=false

# Function to display error messages
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Function to print colored output
print_status() {
    local status=$1
    local color=$2
    echo -e "${color}${status}${NC}"
}

# Function to get CPU usage percentage
get_cpu_usage() {
    # Using top command - gets average CPU usage across all cores
    # Note: This is instantaneous; for average over time, consider using other methods
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d'%' -f1)
    
    # If top fails, try alternative method using /proc/stat
    if [[ -z "$CPU_USAGE" ]] || [[ "$CPU_USAGE" == "0" ]]; then
        CPU_USAGE=$(ps aux | awk '{sum+=$3} END {print sum/NR}')
    fi
    
    # Round to 2 decimal places
    CPU_USAGE=$(printf "%.2f" "$CPU_USAGE")
}

# Function to get memory usage percentage
get_memory_usage() {
    # Using free command - calculates used memory as percentage of total
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.2f", ($3/$2) * 100)}')
}

# Function to get disk usage percentage
get_disk_usage() {
    # Using df command - checks root filesystem (/)
    # Gets the usage percentage of the root partition
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    DISK_USAGE=$(printf "%.2f" "$DISK_USAGE")
}

# Function to determine health status
determine_health_status() {
    local cpu_threshold=$(echo "$CPU_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0)
    local mem_threshold=$(echo "$MEMORY_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0)
    local disk_threshold=$(echo "$DISK_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0)
    
    if [[ "$cpu_threshold" == "1" ]] || [[ "$mem_threshold" == "1" ]] || [[ "$disk_threshold" == "1" ]]; then
        return 1  # NOT HEALTHY
    else
        return 0  # HEALTHY
    fi
}

# Function to print health status
print_health_status() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}     VM HEALTH CHECK REPORT     ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # Print metrics
    echo "Current Metrics:"
    echo "  CPU Usage:     ${CPU_USAGE}%"
    echo "  Memory Usage:  ${MEMORY_USAGE}%"
    echo "  Disk Usage:    ${DISK_USAGE}%"
    echo ""
    echo "Threshold:      ${THRESHOLD}%"
    echo ""
    
    # Determine and print health status
    if determine_health_status; then
        print_status "Health Status: HEALTHY ✓" "$GREEN"
    else
        print_status "Health Status: NOT HEALTHY ✗" "$RED"
    fi
    
    echo ""
}

# Function to print detailed explanation
print_explanation() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  DETAILED HEALTH EXPLANATION  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # CPU Usage Explanation
    echo "CPU USAGE: ${CPU_USAGE}%"
    if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        print_status "  Status: CRITICAL - CPU usage exceeds ${THRESHOLD}% threshold" "$RED"
        echo "  Impact: High CPU utilization may indicate:"
        echo "    • High process load or computationally intensive tasks running"
        echo "    • Potential runaway processes consuming excessive CPU"
        echo "    • Need to investigate top CPU-consuming processes"
    else
        print_status "  Status: NORMAL - CPU usage is within acceptable limits" "$GREEN"
        echo "  Impact: System is operating efficiently with normal CPU load"
    fi
    echo ""
    
    # Memory Usage Explanation
    echo "MEMORY USAGE: ${MEMORY_USAGE}%"
    if (( $(echo "$MEMORY_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        print_status "  Status: CRITICAL - Memory usage exceeds ${THRESHOLD}% threshold" "$RED"
        echo "  Impact: High memory utilization may indicate:"
        echo "    • Memory-intensive applications running on the system"
        echo "    • Memory leaks in running services or applications"
        echo "    • Need to consider memory upgrade or process optimization"
        echo "    • Risk of Out-of-Memory (OOM) killer activating"
    else
        print_status "  Status: NORMAL - Memory usage is within acceptable limits" "$GREEN"
        echo "  Impact: System has sufficient available memory for operations"
    fi
    echo ""
    
    # Disk Usage Explanation
    echo "DISK USAGE: ${DISK_USAGE}%"
    if (( $(echo "$DISK_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        print_status "  Status: CRITICAL - Disk usage exceeds ${THRESHOLD}% threshold" "$RED"
        echo "  Impact: High disk utilization may indicate:"
        echo "    • Limited free space for new data or logs"
        echo "    • Potential risk of disk running out of space"
        echo "    • Applications may fail due to insufficient disk space"
        echo "    • Need to clean up or archive old files and logs"
    else
        print_status "  Status: NORMAL - Disk usage is within acceptable limits" "$GREEN"
        echo "  Impact: Sufficient disk space available for normal operations"
    fi
    echo ""
    
    # Overall Recommendation
    echo -e "${BLUE}================================${NC}"
    echo "OVERALL RECOMMENDATION:"
    echo ""
    if determine_health_status; then
        print_status "✓ Virtual Machine is HEALTHY" "$GREEN"
        echo ""
        echo "Recommendations:"
        echo "  • Continue normal operations and monitoring"
        echo "  • Maintain regular backup schedules"
        echo "  • Monitor trends to catch issues early"
    else
        print_status "✗ Virtual Machine is NOT HEALTHY" "$RED"
        echo ""
        echo "Immediate Actions Required:"
        if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
            echo "  • Investigate CPU usage: run 'top' or 'ps aux' to identify heavy processes"
            echo "  • Kill unnecessary processes or optimize CPU-intensive tasks"
        fi
        if (( $(echo "$MEMORY_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
            echo "  • Check memory usage: run 'free -h' for detailed breakdown"
            echo "  • Restart memory-consuming services or consider memory upgrade"
        fi
        if (( $(echo "$DISK_USAGE > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
            echo "  • Clean up disk space: run 'df -h' to see filesystem breakdown"
            echo "  • Consider cleaning logs, temporary files, or archiving old data"
        fi
    fi
    echo ""
    echo -e "${BLUE}================================${NC}"
}

# Function to display usage information
usage() {
    cat << EOF
${BLUE}VM Health Check Script - Usage${NC}

Usage: $0 [OPTIONS]

Options:
    explain     Display detailed explanation for health status
    -h, --help  Show this help message

Examples:
    $0                    # Display basic health status
    $0 explain            # Display health status with detailed explanation

EOF
}

# Main execution
main() {
    # Parse command-line arguments
    if [[ $# -gt 1 ]]; then
        echo "Error: Too many arguments provided"
        usage
        exit 1
    fi
    
    if [[ $# -eq 1 ]]; then
        case "$1" in
            explain)
                EXPLAIN_FLAG=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown argument '$1'"
                usage
                exit 1
                ;;
        esac
    fi
    
    # Collect system metrics
    echo -e "${YELLOW}Collecting system metrics...${NC}"
    get_cpu_usage
    get_memory_usage
    get_disk_usage
    echo ""
    
    # Print basic health status
    print_health_status
    
    # Print detailed explanation if requested
    if [[ "$EXPLAIN_FLAG" == true ]]; then
        print_explanation
    fi
    
    # Exit with appropriate code
    if determine_health_status; then
        exit 0  # HEALTHY
    else
        exit 1  # NOT HEALTHY
    fi
}

# Run main function
main "$@"
