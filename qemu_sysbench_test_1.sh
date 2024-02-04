#!/bin/bash

# SSH 配置
SSH_USER="abiqemu" # SSH 用户名
SSH_PRIVATE_KEY="/Users/a25076/.ssh/id_rsa" # SSH 私钥的路径
# SSH_PASSWORD="19980903" # SSH 用户密码

# 主机上保存结果的目录
RESULTS_DIR="/Users/a25076/Desktop/241CloudComputing/QEMU/reslut"
mkdir -p $RESULTS_DIR

# Number of runs for each test
num_runs=5

# 测试配置
qemu_configs=(
  "config1:-m 2048 -smp 2" # 2 GB RAM, 2 CPUs
  "config2:-m 1024 -smp 1" # 1 GB RAM, 1 CPU
  "config3:-m 2048 -smp 1" # 2 GB RAM, 1 CPU
  "config4:-m 1024 -smp 2" # 1 GB RAM, 2 CPUs
)

# Sysbench 测试命令
sysbench_tests=(
  "cpu_test1:sysbench cpu --cpu-max-prime=50000 --time=30 run"
  "cpu_test2:sysbench cpu --cpu-max-prime=25000 --time=30 run"
  "memory_test1:sysbench memory --memory-block-size=8M --memory-total-size=4G run"
  "memory_test2:sysbench memory --memory-block-size=4M --memory-total-size=2G run"
  "fileio_test1:sysbench fileio --file-test-mode=rndrw --file-total-size=2G prepare && sysbench fileio --file-test-mode=rndrw --file-total-size=2G run"
  "fileio_test2:sysbench fileio --file-test-mode=seqrewr --file-total-size=1G prepare && sysbench fileio --file-test-mode=seqrewr --file-total-size=1G run"
)

# Function to run tests and process results
run_and_process_test() {
  local config_name="$1"
  local test_name="$2"
  local test_cmd="${sysbench_tests[$test_name]}"
  local result_file="${RESULTS_DIR}/${config_name}_${test_name}.txt"

  echo "Running $test_name on $config_name" > "$result_file"
  
  for (( run=1; run<=num_runs; run++ )); do
    echo "Run $run:" >> "$result_file"
    ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" -p 10023 "$SSH_USER@localhost" "$test_cmd" >> "$result_file"
  done

  # Process the temp file to calculate summary statistics
  # Assuming 'events per second' as the metric to summarize. Adjust the grep/awk pattern as needed for different or multiple metrics.
  echo "Summary for $test_name on $config_name:" >> "$result_file"
  awk '/events per second:/ {print $5}' "$temp_file" | \
  awk 'BEGIN {min=2^31-1; max=0} {sum+=$1; sumsq+=$1*$1; if($1<min){min=$1}; if($1>max){max=$1}; count++} END {print "Average: " sum/count "\nMin: " min "\nMax: " max "\nStd Dev: " sqrt(sumsq/count - (sum/count)^2)}' >> "$result_file"

  # Cleanup temp file
  rm "$temp_file"

  # Add logic here to calculate and append the summary statistics (average, min, max, std) to "$result_file"
}
# 执行测试
for config in "${qemu_configs[@]}"
do
    IFS=":" read -ra config_parts <<< "$config"
    config_name="${config_parts[0]}"
    config_cmd="${config_parts[1]}"

    echo "Running tests for configuration: $config_name"
    
    QEMU_CMD="qemu-system-aarch64 -accel hvf -cpu cortex-a57 -M virt,highmem=off -drive file=/opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on  -drive if=none,file=myrawimage.img,format=raw,id=hd0  -device virtio-blk-device,drive=hd0,serial=\"dummyserial\"  -device virtio-net-device,netdev=net0 -netdev user,id=net0,hostfwd=tcp::10023-:22 -vga none -device ramfb -cdrom /Users/a25076/Desktop/241CloudComputing/ubuntu-20.04.5-live-server-arm64.iso -device usb-ehci -device usb-kbd -device usb-mouse -usb  -nographic $config_cmd"
    $QEMU_CMD &
    QEMU_PID=$!

    echo "QEMU PID: $QEMU_PID"

    sleep 30 # 等待 VM 启动

    for test in "${sysbench_tests[@]}"
    do
        run_and_process_test "$config_name" "$test_name"
    done
    
    if [ ! -z "$QEMU_PID" ]; then
    echo "Attempting to terminate QEMU process with PID: $QEMU_PID"
    kill $QEMU_PID
    sleep 5 # 给一些时间让进程退出

      # 检查进程是否还在运行，并尝试强制终止
      if ps -p $QEMU_PID > /dev/null; then
         echo "Process $QEMU_PID did not terminate gracefully, attempting kill -9."
         kill -9 $QEMU_PID
         sleep 5 # 再次等待进程退出
      fi
    fi

  # 检查端口是否被占用
  if lsof -i :10023; then
      echo "Port 10023 is still in use. Please check and terminate the relevant process."
      pkill -f qemu-system-aarch64
      sleep 5 # 给进程一些时间来终止
      if lsof -i :10023; then
          echo "Failed to terminate QEMU processes. Please check and terminate the relevant process manually."
          exit 1
      fi
  fi
done

echo "All tests completed."
