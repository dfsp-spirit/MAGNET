FROM rocker/r-ver:3.5.3


LABEL org.label-schema.license="GPL-2.0" \
      org.label-schema.vcs-url="https://github.com/sheenyo/MAGNET" \
      maintainer="Tim Schaefer <ts+code@rcmd.org>"

RUN apt-get update \
 && apt-get -y install --no-install-recommends \
 gunzip \
 wget \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir /home/magnet

RUN R -e "options(repos = \
  list(CRAN = 'http://mran.revolutionanalytics.com/snapshot/2019-12-10')); \
  install.packages('fsbrain')"

COPY myscript.R /home/analysis/myscript.R

CMD cd /home/magnet \
  && R -e "source('myscript.R')" \
  && mv /home/analysis/p.csv /home/results/p.csv

#mkdir ~/mydocker/results
#docker run -v ~/mydocker/results:/home/results  analysis
