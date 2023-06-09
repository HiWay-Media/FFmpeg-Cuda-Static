# FFmpeg-Cuda-Static
FFmpeg supports NVENC Cuda encoding
docker buildx build --output type=local,dest=build -t ffmpeg-nonfree:linux -f ./nonfree.Dockerfile .
# il risultato della build su directory /root/ffmpeg-docker/build, le librerie sono essenziali ma vengono duplicate

