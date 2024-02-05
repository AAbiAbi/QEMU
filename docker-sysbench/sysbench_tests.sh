#!/bin/bash

# Define the number of iterations
iterations=5
cpu_tests=("1" "2") # Number of CPUs to test with
memory_tests=("1g" "2g") # Memory limits to test with

results_dir="./sysbench_results"

# Create a directory for test results if it does not exist
mkdir -p "$results_dir"

# CPU Test Loop
for cpus in "${cpu_tests[@]}"; do
  cpu_result_file="$results_dir/cpu_test_${cpus}_cpus.txt"
  echo "Starting CPU test with $cpus CPU(s)" | tee -a "$cpu_result_file"
  for i in $(seq 1 $iterations); do
    echo "Iteration $i for $cpus CPU(s)"
    docker run --rm --cpus="$cpus" my-sysbench-image cpu --cpu-max-prime=20000 run | tee -a "$cpu_result_file"
  done
done

# Memory Test Loop
for memory in "${memory_tests[@]}"; do
  memory_result_file="$results_dir/memory_test_${memory}.txt"
  echo "Starting Memory test with $memory limit" | tee -a "$memory_result_file"
  for i in $(seq 1 $iterations); do
    echo "Iteration $i for $memory memory limit" | tee -a "$memory_result_file"
    docker run --rm --memory="$memory" my-sysbench-image memory --memory-block-size=1M --memory-total-size=10G run | tee -a "$memory_result_file"
  done
done
