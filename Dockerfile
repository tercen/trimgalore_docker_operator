FROM tercen/runtime-r40:4.0.4-1

ENV RENV_VERSION 0.13.0
RUN R -e "install.packages('remotes', repos = c(CRAN = 'https://cran.r-project.org'))"
RUN R -e "remotes::install_github('rstudio/renv@${RENV_VERSION}')"

RUN apt update && apt install -y cutadapt default-jre && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.9.zip && \
    unzip fastqc_v0.11.9.zip && rm fastqc_v0.11.9.zip && \
    chmod +x /FastQC/fastqc && \
    ln -s /FastQC/fastqc /usr/local/bin/fastqc && \
    wget https://github.com/FelixKrueger/TrimGalore/archive/0.6.6.tar.gz && \
    tar -xzf 0.6.6.tar.gz && rm 0.6.6.tar.gz && \
    ln -s /TrimGalore-0.6.6/trim_galore /usr/local/bin/trim_galore

RUN echo "2022/03/15 23:30"

COPY . /operator
WORKDIR /operator

RUN R -e "renv::consent(provided=TRUE);renv::restore(confirm=FALSE)"

ENTRYPOINT [ "R","--no-save","--no-restore","--no-environ","--slave","-f","main.R", "--args"]
CMD [ "--taskId", "someid", "--serviceUri", "https://tercen.com", "--token", "sometoken"]
