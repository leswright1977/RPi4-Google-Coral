# RPi4-Google-Coral
Google Coral on the Raspberry Pi 4

***Update 19 July 2019***
New version of the picam script picam_TPU2.py

This uses the imutils lib to hit framerates of > 90fps using the picam...

***Video up on youtube***
https://youtu.be/T-VjYr7sZC4

***Update 3 July 2019***

I have written a live object detection script (see src/picam_TPU.py)
This is similar to the scripts I used with the NCS2, but for the Coral TPU.
It is a test script, so models and labels are hardcoded. I wanted to it be as close to the original scripts I wrote for the NCS in order to do a fair comparison.

So far, I am getting over 36FPS video and over 36FPS inferencing on a single TPU!
I will do a proper test in the daylight. Room lights at night are not sufficient.

![Screenshot](src/home.gif)

***Update 4 July 2019***

I have written another object detection script for video files (see src/video_TPU.py)
Since we can push video through the loop as fast as we can, it is possible to get 70fps and still do reasonable inferencing!

![Screenshot](src/traffic.gif)


***Getting the Coral to work with the Pi 4***

The Google Coral Edge TPU device can be made to work with the Raspberry Pi 4 

As per the instructions at: https://coral.withgoogle.com/docs/accelerator/get-started/

```bash
wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names
tar xzf edgetpu_api.tar.gz
cd edgetpu_api
```


REPLACE install.sh with the one I have in src

THEN run the script ;-)

Note, when you run the demos, instead of here:
/usr/local/lib/python3.5/dist-packages/edgetpu/demo

you need to be here!:
/usr/local/lib/python3.7/dist-packages/edgetpu/demo

This script does a number of things:

Added:
```bash
  elif [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Recognized as Raspberry Pi 4."
    LIBEDGETPU_SUFFIX=arm32
    HOST_GNU_TYPE=arm-linux-gnueabihf
 ```
    
    
 Fixed this (which caused the script to bomb with "Need To Be Root":
 ```bash
 sudo udevadm control --reload-rules && udevadm trigger
 ```
 to this:
 ```bash
 sudo udevadm control --reload-rules && sudo udevadm trigger  #needed to put sudo in second half of command...
 ```
 
 Finally as Raspian buster uses python 3.7 added:
 ```bash
 if [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Lib Fu."
    sudo cp /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-35m-arm-linux-gnueabihf.so /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-37m-arm-linux-gnueabihf.so
fi
```

Note, all this does is copy the python wrapper (compiled for python 3.5) and use 37 instead of 35 in the filename. 
Terrible undiscovered things may happen, or they may not, but it all seems to work for me!

All the examples supplied in the packages appear to work correctly.
