#! /usr/bin/python
from TOSSIM import *
import sys
import time

t = Tossim([])
r = t.radio()
f = open("topo3.txt", "r")
for line in f:
	s = line.split()
	if s:
		print " ", s[0], " ", s[1], " ", s[2];
		r.add(int(s[0]), int(s[1]), float(s[2]))

Max_Node = 3

t.addChannel("RadioCountToLedsC", sys.stdout)
t.addChannel("Boot", sys.stdout)
t.addChannel("radio_pack", sys.stdout)
t.addChannel("pack_send", sys.stdout)
t.addChannel("pack_recv", sys.stdout)
#t.addChannel("debug_time", sys.stdout)

noise = open("meyer-heavy.txt", "r")
for line in noise:
	str1 = line.strip()
	if str1:
		val = int(str1)
		for i in range(1, Max_Node + 1):
			t.getNode(i).addNoiseTraceReading(val)

for i in range(1, Max_Node + 1):
	print "Creating noise model for ",i;
	t.getNode(i).createNoiseModel();
#time.sleep(5);
t.getNode(1).bootAtTime(100001);
t.getNode(2).bootAtTime(800002);
t.getNode(3).bootAtTime(1200001);
for i in range(10000):
	t.runNextEvent()

# time send source
# time receive source destination sendtime

Send = [0] * Max_Node
Send_Succ = [0] * Max_Node
Delay_Sum = [0] * Max_Node


def cut_line(line):
    item_list = line.split(' ')
    if (len(item_list) < 3):
        return
    now_time_list = item_list[0].split(':')
    now_hour = int(now_time_list[0])
    now_min = int(now_time_list[1])
    now_sec = float(now_time_list[2])

    type = item_list[1]
    send_node = int(item_list[2])
    if (type == 'send'):
        Send[send_node - 1] += Max_Node - 1
    else:
        recv_node = int(item_list[3])
        Send_Succ[send_node - 1] += 1
        send_time_list = item_list[4].split(':')
        # print send_time_list
        send_hour = int(send_time_list[0])
        send_min = int(send_time_list[1])
        send_sec = float(send_time_list[2])
        # print now_hour,now_min,now_sec,send_hour,send_min,send_sec
        # print ''
        delay = (now_hour - send_hour) * 3600 + (now_min - send_min) * 60 + now_sec - send_sec
        delay = delay * 1000
        Delay_Sum[send_node - 1] += delay

log_file = open('log.txt','r')
while 1:
    line = log_file.readline()
    cut_line(line)
    if not line:
        break

tot_send = 0
tot_succ = 0
tot_delay = 0


print "-------------------------------------------------------------"

print "Result:"
for i in range(Max_Node):
    print ('Node %d : Packet Loss Rate = %.2f%s Average Delay = %.2f ms' %
           (i+1,(1 - 1.0*Send_Succ[i] / Send[i]) * 100,'%', Delay_Sum[i] / Send_Succ[i]))
    tot_send += Send[i]
    tot_succ += Send_Succ[i]
    tot_delay += Delay_Sum[i]
print ''
print 'For all : Packet Loss Rate = %.2f%s Average Delay = %.2f ms' % ((1-1.0*tot_succ / tot_send) * 100,'%',tot_delay / tot_succ)




