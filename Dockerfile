FROM tercen/dartrusttidy:travis-17

RUN apt-get update
RUN apt install -y cutadapt

RUN apt-get update
RUN apt install -y default-jre
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip
RUN unzip fastqc_v0.11.9.zip
RUN chmod 755 /FastQC/fastqc
RUN ln -s /FastQC/fastqc /usr/local/bin/fastqc

RUN wget https://github.com/FelixKrueger/TrimGalore/archive/0.6.6.tar.gz
RUN tar xzvf 0.6.6.tar.gz
RUN ln -s /TrimGalore-0.6.6/trim_galore /usr/local/bin/trim_galore

USER root
WORKDIR /operator

RUN git clone https://github.com/tercen/trimgalore_operator.git

WORKDIR /operator/trimgalore_operator

RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron

RUN echo "04/03/2022 22:37" && git pull
RUN echo "04/03/2022 22:37" && git checkout

RUN R -e "install.packages('renv')"
RUN R -e "renv::consent(provided=TRUE);renv::restore(confirm=FALSE)"

ENTRYPOINT [ "R","--no-save","--no-restore","--no-environ","--slave","-f","main.R", "--args"]
CMD [ "--taskId", "someid", "--serviceUri", "https://tercen.com", "--token", "sometoken"]
