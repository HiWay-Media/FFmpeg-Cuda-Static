docker run --rm -it --gpus all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
    --volume $PWD:/code \
    docker-registry.tngrm.io/ffmpeg5-cuda:5.1.2 \
      -hwaccel_device 0 \
      -hwaccel cuvid \
      -c:v h264_cuvid \
      -i input.mp4 \
      -c:v h264_nvenc \
      out.mkv
