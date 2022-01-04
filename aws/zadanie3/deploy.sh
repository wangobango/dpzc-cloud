cp /home/ramon/.aws/credentials ./credentials
docker build -t test1 .
docker run test1
rm credentials