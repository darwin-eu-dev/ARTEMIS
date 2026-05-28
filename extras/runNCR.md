Instructions to install and run ARTEMIS from a docker .tar file. Important: docker must already be installed. 


1) Download .tar file for your OS (amd64 or arm64)

2) In terminal 
`docker image load -i ~/path/to/artemis-rstudio-amd64.tar`

3) `docker image list` should now show sumiyaabdi/artemis

4) `docker run --rm -p 8787:8787 -e PASSWORD=artemis sumiyaabdi/artemis:latest-amd64`

5) Open a browser and go to **localhost:8787**. Enter:
    > username: rstudio

    > password: artemis

6) Open CodeToRun.R, enter your db information and execute the code. 
