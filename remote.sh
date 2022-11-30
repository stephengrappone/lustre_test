#!/bin/bash

iod="32"
bs="1m"
filesize="15g"
numjobs="4"
testtime="500"
now="$(date)"
FILE=/tmp/clients

if test -f "$FILE"; then
    cp /dev/null > $FILE
fi

sudo cp /home/opc/playbooks/sshd_config /etc/ssh/sshd_config
sudo service sshd restart
touch /tmp/clients
sudo chmod 777 /tmp/clients
sudo mkdir -p /tmp/results
sudo chmod 777 /tmp/results
cp /dev/null /tmp/totals
sudo chmod 755 /home/opc/playbooks/_perf_test.sh.j2
sudo chmod 755 /home/opc/playbooks/_reporthome.sh.j2

cd /home/opc/playbooks/
ansible-playbook -i inventory test.yml
mv /tmp/clients .
sleep 2
clientnum=$(cat clients | wc -l)
echo "Testing $clientnum clients"
sleep 2

command="/tmp/perf_test.sh $iod $bs $filesize $numjobs $testtime"
for host in $(cat clients); do ssh -T "$host" "$command" >"output.$host" &
done

touch /tmp/results/total
cp /dev/null /tmp/results/total
touch /tmp/results/client-1
sudo rm /tmp/results/client-1

echo "test is running"
while [ ! -f /tmp/results/client-1 ]; do sleep 1; done
echo "gathering information"
sleep 25

cat /tmp/results/client* >> /tmp/results/total
cat /tmp/results/total | grep read | awk '{print$2}' >> /tmp/rtotals
cat /tmp/results/total | grep write | awk '{print$2}' >> /tmp/wtotals

totalrresults=$(awk '{ sum += $1 } END { print sum }' /tmp/rtotals)
totalwresults=$(awk '{ sum += $1 } END { print sum }' /tmp/wtotals)

echo "Total read: $totalrresults MB/s"
echo "Total write: $totalwresults MB/s"

echo "tested on $now" >> /tmp/final_results
echo "tested on $clientnum clients" >> /tmp/final_results
echo "Total read: $totalrresults MB/s" >> /tmp/final_results
echo "Total write: $totalwresults MB/s" >> /tmp/final_results
echo "iodepth $iod" >> /tmp/final_results
echo "blocksize $bs" >> /tmp/final_results
echo "filesize $filesize" >> /tmp/final_results
echo "number of jobs $numjobs" >> /tmp/final_results
echo "runtime $testtime" >> /tmp/final_results
sleep 2

curl -s https://objectstorage.us-ashburn-1.oraclecloud.com/p/mrZU2q9AL-DtVVKoyb9l1PDRSLZYPLuGk-nHUsqH1VvRJOLQ9dFIm8rVbBD2M1WH/n/hpc_limited_availability/b/results/o/ --upload-file /tmp/final_results
sleep 2
echo "cleaning up files"
sudo rm /home/opc/playbooks/clients
sudo rm /home/opc/playbooks/output.client-*
sudo rm /tmp/rtotals
sudo rm /tmp/wtotals
sudo rm /tmp/totals
sudo rm -rf /tmp/results
sudo rm /tmp/final_results

echo "complete"
