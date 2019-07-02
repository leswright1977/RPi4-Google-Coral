# RPi4-Google-Coral
Google Coral on the Raspberry Pi 4


The Google Coral Edge TPU device can be made to work with the Raspberry Pi 4 

As per the instructions at: https://coral.withgoogle.com/docs/accelerator/get-started/

wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names
tar xzf edgetpu_api.tar.gz
cd edgetpu_api


REPLACE install.sh with the one I have in src

THEN run the script ;-)

This script does a number of things:

Added:
  elif [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Recognized as Raspberry Pi 4."
    LIBEDGETPU_SUFFIX=arm32
    HOST_GNU_TYPE=arm-linux-gnueabihf
    
    
 Fixed this:
 sudo udevadm control --reload-rules && udevadm trigger 
 to this:
 sudo udevadm control --reload-rules && sudo udevadm trigger  #needed to put sudo in second half of command...
 
 Finally as Raspian buster uses python 3.7 added:
 
 if [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Lib Fu."
    sudo cp /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-35m-arm-linux-gnueabihf.so /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-37m-arm-linux-gnueabihf.so
fi

Note, all this does is copy the python wrapper (compiled for python 3.5) and use 37 instead of 35 in the filename. 
Terrible undiscovered things may happen, or they may not, but it all seems to work for me!

All the examples supplied in the packages appear to work correctly.
