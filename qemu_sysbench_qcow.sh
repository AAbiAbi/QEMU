#!/bin/bash

# SSH 配置
SSH_USER="abiqemu" # SSH 用户名
SSH_PRIVATE_KEY="/Users/a25076/.ssh/id_rsa" # SSH 私钥的路径

# 主机上保存结果的目录
RESULTS_DIR="/Users/a25076/Desktop/241CloudComputing/QEMU/result_qcow_1"
mkdir -p "${RESULTS_DIR}"

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

# 每个测试用例重复次数
REPEAT_TIMES=5

# 执行测试并计算统计数据
for config in "${qemu_configs[@]}"
do
    IFS=":" read -ra config_parts <<< "$config"
    config_name="${config_parts[0]}"
    config_cmd="${config_parts[1]}"

    echo "Running tests for configuration: $config_name"
    
    # 启动QEMU VM
    QEMU_CMD="qemu-system-aarch64 -accel hvf -cpu cortex-a57 -M virt,highmem=off -drive file=/opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on -drive if=none,file=myqcow2image.qcow2,format=qcow2,id=hd0 -device virtio-blk-device,drive=hd0,serial=\"dummyserial\" -device virtio-net-device,netdev=net0 -netdev user,id=net0,hostfwd=tcp::10022-:22 -vga none -device ramfb -device usb-ehci -device usb-kbd -device usb-mouse -usb -nographic $config_cmd"
    $QEMU_CMD &
    QEMU_PID=$!
    echo "QEMU PID: $QEMU_PID"
    sleep 30 # 等待 VM 启动

    for test in "${sysbench_tests[@]}"
    do
        IFS=":" read -ra test_parts <<< "$test"
        test_name="${test_parts[0]}"
        test_cmd="${test_parts[1]}"
        
        # 初始化统计变量
        total_time=0
        min_time=999999
        max_time=0
        times=()

        # 重复执行测试并收集数据
        for (( i=0; i<REPEAT_TIMES; i++ ))
        do

            # Clear cache before running fileio tests
            if [[ "$test_name" == "fileio_test1" ]] || [[ "$test_name" == "fileio_test2" ]]; then
                clear_cache
            fi
            
            echo "Running $test_name on $config_name, iteration $((i+1))"
            result=$(ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" -p 10022 "$SSH_USER@localhost" "$test_cmd")
            # 这里假设你能从result中提取出执行时间或者其他的性能指标
            # 你需要根据sysbench的输出格式来提取出你感兴趣的数据
            # 例如: time=$(echo "$result
# 将结果追加到文件
            echo "$result" >> "${RESULTS_DIR}/${config_name}_${test_name}.txt"
        done

        # 计算平均值、最小值、最大值、标准差等
        # echo "Average: ..., Min: ..., Max: ..., Std: ..." >> "${RESULTS_DIR}/${config_name}_${test_name}.txt"
    done

    # 关闭QEMU VM
    if [ ! -z "$QEMU_PID" ]; then
        kill $QEMU_PID
    fi
done

echo "All tests completed."


# Add a function to clear cache on the host system
clear_cache() {
  echo "Clearing cache on the host system..."
  ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" -p 10022 "$SSH_USER@localhost" "echo 'echo 3 > /proc/sys/vm/drop_caches' | sudo sh"
}
