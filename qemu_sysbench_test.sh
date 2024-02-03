#!/bin/bash

# Directory to store results
RESULTS_DIR="sysbench_results"
mkdir -p $RESULTS_DIR

# Number of total runs for each test
RUNS=5

# Memory Tests
MEMORY_BLOCK_SIZES=("1M" "512K") # Two different block sizes for memory test
MEMORY_TOTAL_SIZE="1G" # Total size for memory test

# File IO Tests
FILE_TEST_MODES=("rndrw" "seqrewr") # Two different test modes for file IO test
FILE_SIZE="1G" # File size for file IO test

# Running tests
echo "Starting Sysbench Tests"

# Function to run tests
run_tests() {
    test_type=$1
    options=$2
    filename=$3

    for (( i=1; i<=$RUNS; i++ ))
    do
        echo "Running $test_type test iteration $i..."
        sysbench $test_type $options run | tee -a "$RESULTS_DIR/${filename}_run_$i.txt"
    done
}

# Running CPU tests
for max_prime in "${CPU_MAX_PRIMES[@]}"
do
    options="cpu --cpu-max-prime=$max_prime --time=$CPU_TEST_TIME"
    run_tests "cpu" "$options" "cpu_max_prime_${max_prime}"
done

# Running Memory tests
for block_size in "${MEMORY_BLOCK_SIZES[@]}"
do
    options="memory --memory-block-size=$block_size --memory-total-size=$MEMORY_TOTAL_SIZE"
    run_tests "memory" "$options" "memory_block_size_${block_size}"
done

# Running File IO tests
for test_mode in "${FILE_TEST_MODES[@]}"
do
    options="fileio --file-total-size=$FILE_SIZE --file-test-mode=$test_mode"
    sysbench $options prepare
    run_tests "fileio" "$options" "fileio_test_mode_${test_mode}"
    sysbench $options cleanup
done

echo "Sysbench Tests Completed"
