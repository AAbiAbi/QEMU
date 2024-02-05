#!/usr/bin/env bash


# Docker 配置
docker_image="my-sysbench-image"  # 使用之前创建的 Docker 镜像名称

# 主机上保存结果的目录
results_dir="result_1"
mkdir -p "$results_dir"


# Number of runs for each test
num_runs=5

# 定义测试配置 
declare -A docker_configs=(
  ["config1"]="--cpus=2 --memory=2g"
  ["config2"]="--cpus=1 --memory=1g"
  ["config3"]="--cpus=1 --memory=2g"
  ["config4"]="--cpus=2 --memory=1g"
)

# 定义 Sysbench 测试命令
declare -A sysbench_tests=(
  ["cpu_test1"]="sysbench cpu --cpu-max-prime=50000 --time=30 run"
  ["cpu_test2"]="sysbench cpu --cpu-max-prime=25000 --time=30 run"
  ["memory_test1"]="sysbench memory --memory-block-size=8M --memory-total-size=4G run"
  ["memory_test2"]="sysbench memory --memory-block-size=4M --memory-total-size=2G run"
  ["fileio_test1"]="sysbench fileio --file-test-mode=rndrw --file-total-size=2G prepare && sysbench fileio --file-test-mode=rndrw --file-total-size=2G run"
  ["fileio_test2"]="sysbench fileio --file-test-mode=seqrewr --file-total-size=1G prepare && sysbench fileio --file-test-mode=seqrewr --file-total-size=1G run"
)

# Function to run and process tests
run_and_process_test() {
  local config_name="$1"
  local test_name="$2"
  local docker_config="${docker_configs[$config_name]}"
  local sysbench_command="${sysbench_tests[$test_name]}"
  local result_file="${results_dir}/${config_name}_${test_name}.txt"

  echo "Running $test_name on $config_name" | tee "$result_file"
  
  for (( run=1; run<=num_runs; run++ )); do
    echo "Run $run:" | tee -a "$result_file"
    docker run --rm $docker_config $docker_image /bin/bash -c "$sysbench_command" | tee -a "$result_file"
  done

  # You can add commands here to process the results (e.g., calculate average, min, max, std) from "$result_file"
}

# Execute tests
for config_name in "${!docker_configs[@]}"; do
  for test_name in "${!sysbench_tests[@]}"; do
    run_and_process_test "$config_name" "$test_name"
  done
done


echo "All tests completed."
