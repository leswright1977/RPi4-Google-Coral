import cv2
import time
import numpy as np
from multiprocessing import Process
from multiprocessing import Queue
from picamera.array import PiRGBArray
from picamera import PiCamera

import edgetpu.detection.engine
from edgetpu.utils import image_processing
from PIL import Image



#Misc vars
font = cv2.FONT_HERSHEY_SIMPLEX
queuepulls = 0.0
detections = 0
fps = 0.0
qfps = 0.0
confThreshold = 0.6

#initialize the camera and grab a reference to the raw camera capture
frameWidth = 304
frameHeight = 304
camera = PiCamera()
camera.resolution = (frameWidth,frameHeight)
camera.framerate = 40
rawCapture = PiRGBArray(camera, size=(frameWidth,frameHeight)) 

# allow the camera to warmup
time.sleep(0.1)


labels_file = 'tpu_models/coco_labels.txt'
# Read labels from text files. Note, there are missing items from the coco_labels txt hence this!
labels = [None] * 10
with open(labels_file, 'r') as f:
	lines = f.readlines()
for line in lines:
	parts = line.strip().split(maxsplit=1)
	labels.insert(int(parts[0]),str(parts[1])) 
	
print(labels)


#define the function that handles our processing thread
def classify_frame(img, inputQueue, outputQueue):
	engine = edgetpu.detection.engine.DetectionEngine(\
	'tpu_models/mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite')
	# keep looping
	while True:
		# check to see if there is a frame in our input queue
		if not inputQueue.empty():
			# grab the frame from the input queue
			img = inputQueue.get()
			results = engine.DetectWithImage(img, threshold=0.4,\
			keep_aspect_ratio=True, relative_coord=False, top_k=10)

			data_out = []

			if results:
				for obj in results:
					inference = []
					box = obj.bounding_box.flatten().tolist()
					xmin = int(box[0])
					ymin = int(box[1])
					xmax = int(box[2])
					ymax = int(box[3])

					inference.extend((obj.label_id,obj.score,xmin,ymin,xmax,ymax))
					data_out.append(inference)
			outputQueue.put(data_out)
		

# initialize the input queue (frames), output queue (out),
# and the list of actual detections returned by the child process
inputQueue = Queue(maxsize=1)
outputQueue = Queue(maxsize=1)
img = None
out = None

# construct a child process *indepedent* from our main process of
# execution
print("[INFO] starting process...")
p = Process(target=classify_frame, args=(img,inputQueue,outputQueue,))
p.daemon = True
p.start()

print("[INFO] starting capture...")

#time the frame rate....
timer1 = time.time()
frames = 0
queuepulls = 0
timer2 = 0
t2secs = 0

for frame in camera.capture_continuous(rawCapture, format="bgr", use_video_port=True):
	if queuepulls ==1:
		timer2 = time.time()
	# Capture frame-by-frame
	frame = frame.array

	img = Image.fromarray(frame)


	# if the input queue *is* empty, give the current frame to
	# classify
	if inputQueue.empty():
		inputQueue.put(img)

	# if the output queue *is not* empty, grab the detections
	if not outputQueue.empty():
		out = outputQueue.get()

	if out is not None:
		# loop over the detections
		for detection in out:
			objID = detection[0]
			labeltxt = labels[objID]
			confidence = detection[1]
			xmin = detection[2]
			ymin = detection[3]
			xmax = detection[4]
			ymax = detection[5]
			if confidence > confThreshold:
				#bounding box
				cv2.rectangle(frame, (xmin, ymin), (xmax, ymax), color=(0, 255, 255))
				#label
				labLen = len(labeltxt)*5+40
				cv2.rectangle(frame, (xmin-1, ymin-1),\
				(xmin+labLen, ymin-10), (0,255,255), -1)
				#labeltext
				cv2.putText(frame,' '+labeltxt+' '+str(round(confidence,2)),\
				(xmin,ymin-2), font, 0.3,(0,0,0),1,cv2.LINE_AA)
				detections +=1 #positive detections
	
		queuepulls += 1

	# Display the resulting frame
	cv2.rectangle(frame, (0,0),\
	(frameWidth,25), (0,0,0), -1)

	cv2.rectangle(frame, (0,frameHeight-25),\
	(frameWidth,frameHeight), (0,0,0), -1)

	cv2.putText(frame,'Threshold: '+str(round(confThreshold,1)), (10, 10),\
	cv2.FONT_HERSHEY_SIMPLEX, 0.3,(0, 255, 255), 1, cv2.LINE_AA)

	cv2.putText(frame,'VID FPS: '+str(fps), (frameWidth-80, 10),\
	cv2.FONT_HERSHEY_SIMPLEX, 0.3,(0, 255, 255), 1, cv2.LINE_AA)

	cv2.putText(frame,'TPU FPS: '+str(qfps), (frameWidth-80, 20),\
	cv2.FONT_HERSHEY_SIMPLEX, 0.3,(0, 255, 255), 1, cv2.LINE_AA)

	cv2.putText(frame,'Positive detections: '+str(detections), (10, frameHeight-10),\
 	cv2.FONT_HERSHEY_SIMPLEX, 0.3,(0, 255, 255), 1, cv2.LINE_AA)

	cv2.putText(frame,'Elapsed time: '+str(round(t2secs,2)), (150, frameHeight-10),\
 	cv2.FONT_HERSHEY_SIMPLEX, 0.3,(0, 255, 255), 1, cv2.LINE_AA)
	

	cv2.namedWindow('Coral',cv2.WINDOW_NORMAL)
	cv2.resizeWindow('Coral',frameWidth,frameHeight)
	cv2.imshow('Coral',frame)
	
	# FPS calculation
	frames += 1
	if frames >= 1:
		end1 = time.time()
		t1secs = end1-timer1
		fps = round(frames/t1secs,2)
	if queuepulls > 1:
		end2 = time.time()
		t2secs = end2-timer2
		qfps = round(queuepulls/t2secs,2)

	# clear the stream in preparation for the next frame
	rawCapture.truncate(0)

	keyPress = cv2.waitKey(1)
	if keyPress == 113:
        	break
	if keyPress == 82:
		confThreshold += 0.1
	if keyPress == 84:
		confThreshold -= 0.1
	if confThreshold >1:
		confThreshold = 1
	if confThreshold <0.4:
		confThreshold = 0.4

cv2.destroyAllWindows()


