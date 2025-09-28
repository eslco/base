#!/bin/bash
log file="/var/log/auth.log" #日志文件路径
#输出表头和分隔线
echo "IP地址         失败次数"
echo

# 使用 awk 统计录失Failed的 IP 和次数，并排序输出

awk '
/Failed password/ {
 # 提取 IP 地址
  for (i=1; i<= NF; i++) {
     if($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/){
     ip = $i
    break

#统计IP出现次数
if(ip) {
    ip count[ip]++
   }
}

END {
 # 输出统计结果
  for(ip in ip count) {
     printf "$-15s\t&d\n", ip, ip_count[ip]
    }
}' $log file|sort-k2 -nr #按Failed次数从高到低排序