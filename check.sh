#!/bin/bash
clear
# In model của mainboard
echo "-------------------------------"
echo "Model của mainboard:"
sudo dmidecode -t 2 | grep "Product Name"

echo "-------------------------------"

# In số lượng CPU vật lý và tên của CPU
echo -e "\nThông tin về CPU:"
cpu_sockets=$(lscpu | grep "Socket(s)" | awk -F: '{print $2}' | tr -d ' ')
echo "Số lượng CPU vật lý: $cpu_sockets"
echo "Tên CPU:"
lscpu | grep "Model name" | awk -F: '{print $2}'

echo "-------------------------------"

# In thông tin model và serial của tất cả các ổ cứng
echo -e "\nThông tin ổ cứng (Model và Serial):"
lsblk -d -o NAME,MODEL,SERIAL
echo "-------------------------------"

# In thông tin các card đồ họa từ lspci và nvidia-smi
echo -e "\nThông tin các card đồ họa:"
# Lấy thông tin từ lspci
lspci | grep -i vga | while read -r line; do
    echo $line
done

# Lấy thông tin GPU từ nvidia-smi (tên GPU và dung lượng VRAM)
if command -v nvidia-smi &>/dev/null; then
    echo -e "\nThông tin GPU từ nvidia-smi (Tên và Dung lượng VRAM):"
    nvidia-smi --query-gpu=gpu_name,memory.total --format=csv,noheader
else
    echo "Không tìm thấy nvidia-smi, không thể lấy thông tin GPU NVIDIA."
fi



echo "-------------------------------"

# In số lượng RAM và dung lượng của từng thanh RAM
echo -e "\nThông tin về RAM:"
total_memory=$(free -h | grep Mem | awk '{print $2}')
echo "Tổng bộ nhớ RAM: $total_memory"
#echo "Thông tin về từng thanh RAM:"
#sudo dmidecode -t memory | grep -i -e 'Size' -e 'Locator'
