#!/bin/bash

ENERGY_PATH="/sys/class/powercap/intel-rapl:0/energy_uj"
MAX_LINES=3
declare -a lines=()
declare -a cpu_log=()
declare -a gpu_log=()
declare -a total_log=()

cpu_name=$(lscpu | grep 'Model name' | awk -F: '{print $2}' | sed 's/^[ \t]*//')
gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
start_time=$(date +%s)

clear
while true; do
    # CPU watt
    awal=$(cat "$ENERGY_PATH")
    sleep 1
    akhir=$(cat "$ENERGY_PATH")
    delta=$((akhir - awal))
    cpu_watt=$(echo "scale=2; $delta / 1000000" | LC_NUMERIC=C bc)

    # GPU watt
    gpu_watt=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
    gpu_watt=$(echo "$gpu_watt" | tr -d '[:space:]')

    # Total watt
    total_watt=$(echo "scale=2; $cpu_watt + $gpu_watt" | LC_NUMERIC=C bc)

    # Timestamp
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Simpan log untuk statistik
    cpu_log+=("$cpu_watt")
    gpu_log+=("$gpu_watt")
    total_log+=("$total_watt")

    # Format baris
    line=$(LC_NUMERIC=C printf "%-20s | %11.2f W | %11.2f W | %11.2f W" "$ts" "$cpu_watt" "$gpu_watt" "$total_watt")

    # Tambah ke buffer tampilan
    lines+=("$line")
    if [ ${#lines[@]} -gt $MAX_LINES ]; then
        lines=("${lines[@]:1}")
    fi

    # Hitung summary
    cpu_min=$(printf "%s\n" "${cpu_log[@]}" | LC_NUMERIC=C sort -n | head -1)
    cpu_max=$(printf "%s\n" "${cpu_log[@]}" | LC_NUMERIC=C sort -n | tail -1)
    cpu_avg=$(echo "${cpu_log[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; printf("%.2f", sum/NF)}')

    gpu_min=$(printf "%s\n" "${gpu_log[@]}" | LC_NUMERIC=C sort -n | head -1)
    gpu_max=$(printf "%s\n" "${gpu_log[@]}" | LC_NUMERIC=C sort -n | tail -1)
    gpu_avg=$(echo "${gpu_log[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; printf("%.2f", sum/NF)}')

    total_min=$(printf "%s\n" "${total_log[@]}" | LC_NUMERIC=C sort -n | head -1)
    total_max=$(printf "%s\n" "${total_log[@]}" | LC_NUMERIC=C sort -n | tail -1)
    total_avg=$(echo "${total_log[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; printf("%.2f", sum/NF)}')

    # Hitung durasi monitoring
    now_time=$(date +%s)
    duration=$((now_time - start_time))
    duration_fmt=$(printf "%02d:%02d:%02d" $((duration/3600)) $(((duration%3600)/60)) $((duration%60)))

    # Tampilkan
    clear
    echo ""
    echo "                            Show Watt?"
    echo "                      $(date '+%Y-%m-%d') - $(hostname)"
    echo ""
    echo " CPU : $cpu_name"
    echo " GPU : $gpu_name"
    echo 
    echo " =====================+===============+===============+==============="
    echo " Timestamp            |   CPU Power   |   GPU Power   |   Total Power"
    echo " =====================+===============+===============+==============="
    for entry in "${lines[@]}"; do
        echo " $entry"
    done
    echo "---------------------+---------------+---------------+---------------"
    echo
    echo " Summary ($duration_fmt):"
    LC_NUMERIC=C printf "   CPU   ->  Min: %5.2f W   Max: %5.2f W   Avg: %5.2f W\n" "$cpu_min" "$cpu_max" "$cpu_avg"
    LC_NUMERIC=C printf "   GPU   ->  Min: %5.2f W   Max: %5.2f W   Avg: %5.2f W\n" "$gpu_min" "$gpu_max" "$gpu_avg"
    LC_NUMERIC=C printf "   Total ->  Min: %5.2f W   Max: %5.2f W   Avg: %5.2f W\n" "$total_min" "$total_max" "$total_avg"
    echo
done
