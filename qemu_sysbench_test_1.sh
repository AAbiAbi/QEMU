#!/bin/bash

# SSH 配置
SSH_HOST="localhost"
SSH_PORT=10022
SSH_USER="abiqemu" # SSH 用户名
SSH_PRIVATE_KEY="/Users/a25076/.ssh/id_rsa" # SSH 私钥的路径
SSH_PASSWORD="19980903" # SSH 用户密码

QEMU_BASE_CMD="qemu-system-aarch64 -accel hvf -cpu cortex-a57 -M virt,highmem=off -drive file=/opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on  -drive if=none,file=myqcow2image.qcow2,format=qcow2,id=hd0  -device virtio-blk-device,drive=hd0,serial="dummyserial"  -device virtio-net-device,netdev=net0 -netdev user,id=net0,hostfwd=tcp::10022-:22 -vga none -device ramfb -device usb-ehci -device usb-kbd -device usb-mouse -usb  -nographic"

# 主机上保存结果的目录
RESULTS_DIR="/Users/a25076/Desktop/241CloudComputing/QEMU/result"
mkdir -p $RESULTS_DIR


# 测试配置
qemu_configs=(
  "config1:-m 2048 -smp 2" # 2 GB RAM, 2 CPUs
  "config2:-m 1024 -smp 1" # 1 GB RAM, 1 CPU
  "config3:-m 2048 -smp 1" # 2 GB RAM, 1 CPU
  "config4:-m 1024 -smp 2" # 1 GB RAM, 2 CPUs
)


# Sysbench 测试命令
sysbench_tests=(
  "cpu_test1:sysbench cpu --cpu-max-prime=50000 run"
  "cpu_test2:sysbench cpu --cpu-max-prime=25000 run"
  "memory_test1:sysbench memory --memory-block-size=1M --memory-total-size=1G run"
  "memory_test2:sysbench memory --memory-block-size=512K --memory-total-size=512M run"
  "fileio_test1:sysbench fileio --file-test-mode=rndrw --file-total-size=1G prepare && sysbench fileio --file-test-mode=rndrw --file-total-size=1G run"
  "fileio_test2:sysbench fileio --file-test-mode=seqrw --file-total-size=512M prepare && sysbench fileio --file-test-mode=seqrw --file-total-size=512M run"
)

# 执行测试
for config_name in "${!qemu_configs[@]}"
do
     IFS=":" read -ra config_parts <<< "$config"
    config_name="${config_parts[0]}"
    config_cmd="${config_parts[1]}"

    echo "Running tests for configuration: $config_name"
    
    QEMU_CMD="qemu-system-aarch64 -accel hvf -cpu cortex-a57 -M virt,highmem=off -drive file=/opt/homebrew/Cellar/qemu/8.2.1/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on  -drive if=none,file=myqcow2image.qcow2,format=qcow2,id=hd0  -device virtio-blk-device,drive=hd0,serial=\"dummyserial\"  -device virtio-net-device,netdev=net0 -netdev user,id=net0,hostfwd=tcp::10022-:22 -vga none -device ramfb -device usb-ehci -device usb-kbd -device usb-mouse -usb  -nographic $config_cmd"
    $QEMU_CMD &
    QEMU_PID=$!

    echo $QEMU_PID

    sleep 30 # 等待 VM 启动

    for test_name in "${!sysbench_tests[@]}"
    do
        echo "Running $test_name on $config_name"
        sshpass -p "$SSH_PASSWORD" ssh "$SSH_USER@$SSH_HOST" "${sysbench_tests[$test_name]}" > "$RESULTS_DIR/${config_name}_${test_name}.txt"
    done
    
    # pkill -f "qemu-system-aarch64"
    kill $QEMU_PID
    wait $QEMU_PID 2>/dev/null
    sleep 5
done

echo "All tests completed."
