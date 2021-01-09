#include "Timer.h"
#include "RadioCountToLeds.h"
#include <netinet/in.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>

module RadioCountToLedsC @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface AMPacket;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
    interface Packet;
  }
}
//
implementation {
  int cnt = 0;
  uint32_t drop=0;
  uint32_t succ=0;
  uint32_t counter=0;
  uint32_t send[4]={0,0,0,0};
  uint32_t get[4]={0,0,0,0};
  float Drate[4]={0,0,0,0};
  float rate = 0.0;
  message_t packet;

  bool locked;
  bool RLocked=FALSE;
  char buf[1024];
  char trans[1024];
	
	void clearFile()
	{
		FILE *fd = fopen("log.txt", "w+");
		if(fd==0)
		{
			printf("***********************ERROR!***********************\n");
			exit(0);
		}
		fclose(fd);
	}

  void writeFile(int flag,int hour,int min,double now_sec,uint32_t send,uint32_t receive,int shour,int smin,double ssec)
  {
        //读写并追加方式
        FILE *fd = fopen("log.txt", "a+");

        if(fd==0)
				{
					printf("***********************ERROR!***********************\n");
					exit(0);
				}

        //printf("sucess fd = %d\n", fd);
        memset(buf, 0, sizeof(buf));
        memset(trans, 0, sizeof(trans));

        sprintf(trans,"%d",hour);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, ":");
         sprintf(trans,"%d",min);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, ":");
        sprintf(trans,"%f",now_sec);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, " ");
        
        if(flag==1)
        {
        strcat(buf, "send ");
        sprintf(trans,"%d",send);
        strcat(buf,trans);
        }
        else
        {
        strcat(buf, "receive ");
        sprintf(trans,"%d",send);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, " ");
        sprintf(trans,"%d",receive);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, " ");
        sprintf(trans,"%d",shour);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, ":");
         sprintf(trans,"%d",smin);
        strcat(buf,trans);
        memset(trans, 0, sizeof(trans));
        strcat(buf, ":");
        sprintf(trans,"%f",ssec);
        strcat(buf,trans);
        }

        strcat(buf,"  \n");
        memset(trans, 0, sizeof(trans));
        //printf("write %s",buf);
        fprintf(fd, buf);
        memset(buf, 0, sizeof(buf));

        fclose(fd);

}
  
  event void Boot.booted() {
    dbg("Boot", "Application booted.\n");
	clearFile();
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call MilliTimer.startPeriodic(250);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void MilliTimer.fired() {
    unsigned long long t,tot_sec,tot_min;
    int hour,min,sec;
    double now_sec;
    uint16_t pos=0;
    counter++;
    cnt ++;
    dbg("RadioCountToLedsC", "[Time %s] RadioCountToLedsC: timer fired, counter is %hu.\n",sim_time_string(), counter);
    if (locked) {
      return;
    }
    else {
      radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(radio_count_msg_t));
      if (rcm == NULL) {
        return;
      }

      rcm->counter = counter;

      t = sim_time();

      tot_sec = t / 10000000000;
      sec = (tot_sec % 60) * 10000000 + (t % 10000000000) / 1000;
      tot_min = tot_sec / 60;
      min = tot_min % 60;
      hour = tot_min / 60;
      rcm->hour = htons(hour);
      rcm->min = htons(min);
      rcm->sec = htonl(sec);
      now_sec = sec / 10000000.0;
  

      rcm->sender = call AMPacket.source(&packet);
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
      pos=rcm->sender-1;
      send[pos]++;
      writeFile(1,hour,min,now_sec,rcm->sender,0,0,0,0);
        dbg("pack_send", "[Time %d:%d:%.3f] Send packet %hhu,sender is %hhu.\n",hour,min,now_sec, counter, rcm->sender); 
        

        locked = TRUE;
      }
    }

  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    unsigned long long t,tot_sec,tot_min;
    //now time    
    int hour,min;
    double sec;
    uint16_t id;

    double delay;
    
    
    //send time
    int send_hour,send_min;
    float send_sec;
    radio_count_msg_t* rcm;

    if (len != sizeof(radio_count_msg_t)) {return bufPtr;}
    else
    {
      if(RLocked)
        {return;}
      else
      {
        RLocked=TRUE;
        rcm = (radio_count_msg_t*)payload;
        send_hour = ntohs(rcm->hour);
        send_min = ntohs(rcm->min);
        send_sec = ntohl(rcm->sec) / 10000000.0;

        t = sim_time();

        tot_sec = t / 10000000000;
        sec = (tot_sec % 60) * 10000000 + (t % 10000000000) / 1000;
        sec = sec / 10000000.0;
        tot_min = tot_sec / 60;
        min = tot_min % 60;
        hour = tot_min / 60;
        rcm->hour = htonl(hour);
        rcm->min = htonl(min);
        rcm->sec = htonl(sec);

        id=TOS_NODE_ID;
        succ++;
        drop=counter-succ;
      counter=drop+succ;
        rate=(drop * 1.0) / counter;
        delay=((hour-send_hour)*60*60+(min-send_min)*60+sec-send_sec)*1000;
       get[id-1]++;
        dbg("pack_recv", "[Time %d:%d:%.3f] Received packet %hhu of length %hhu from %hhu,send time is %d:%d:%.3f, the delay is %.2lf msecs.\n",hour,min,sec, rcm->counter,  len,id,send_hour,send_min,send_sec,delay);
        //dbg("pack_recv","Now the rate of drop is %hhu, %hhu / %hhu, %0.3lf\n",succ, drop,counter,rate);
        writeFile(2,hour,min,sec,rcm->sender,id,send_hour,send_min,send_sec);
        RLocked=FALSE;
       

        if (rcm->counter & 0x1) {
          call Leds.led0On();
        }
        else {
          call Leds.led0Off();
        }
        if (rcm->counter & 0x2) {
          call Leds.led1On();
        }
        else {
          call Leds.led1Off();
        }
        if (rcm->counter & 0x4) {
          call Leds.led2On();
        }
        else {
          call Leds.led2Off();
        }
        return bufPtr;
      }
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr) {
      locked = FALSE;
    }
  }
}






