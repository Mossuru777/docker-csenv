################################################################################
# Perl5.26.3 with ImageMagick6.9.10-86
# Stage Name: perl5.26.3-with-imagemagick6.9.10-86
################################################################################
FROM perl:5.26.3-buster AS perl5.26.3-with-imagemagick6.9.10-86
MAINTAINER Mossuru777 "mossuru777@gmail.com"

# Setup
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -q -y update \
    && apt-get -q -y autoremove \
         imagemagick \
         imagemagick-6.q16 \
         imagemagick-6-common \
    && apt-get -q -y install --no-install-recommends \
         sed \
         locales \
         tzdata \
    && sed -i -e 's/^# *\(ja_JP.UTF-8.*\)/\1/' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=ja_JP.UTF-8 \
    && ldconfig
ENV TZ Asia/Tokyo

# Install ImageMagick & PerlMagick
WORKDIR /usr/src/imagemagick
RUN apt-get -y install --no-install-recommends \
      libgif7 \
      libgif-dev \
      libpng16-16 \
      libpng-dev \
    && curl -sSL https://github.com/ImageMagick/ImageMagick6/archive/refs/tags/6.9.10-86.tar.gz -o imagemagick-6.9.10-86.tar.gz \
    && echo '82c585b4d1fa599a5fd510342c552c20e6b0edab4d837a62aaaed34b5b356890  imagemagick-6.9.10-86.tar.gz' | sha256sum -c - \
    && tar --strip-components=1 -xaf imagemagick-6.9.10-86.tar.gz -C /usr/src/imagemagick \
    && rm imagemagick-6.9.10-86.tar.gz \
    && ./configure LDFLAGS="-L/usr/local/lib/perl5/5.26.3/x86_64-linux-gnu/CORE" --enable-shared --with-perl=/usr/local/bin/perl \
    && make -j$(nproc) \
    && make install \
    && cd /root \
    && rm -fr /usr/src/imagemagick /tmp/** \
    && ldconfig

# Clean up Apt Cache
RUN apt-get -q -y clean \
    && rm -rf /var/lib/apt/lists/*

# Define default command (Enter shell.)
WORKDIR /root
CMD ["/bin/bash"]



################################################################################
# CSEnv
# Stage Name: csenv
################################################################################
FROM perl5.26.3-with-imagemagick6.9.10-86 AS csenv

# Install CPAN modules
COPY cpanfile /tmp/
RUN cpanm --notest --installdeps /tmp \
    && rm -fr /root/.cpanm /tmp/**

# Define default command (Enter shell.)
WORKDIR /root
CMD ["/bin/bash"]



################################################################################
# Common CSEnv for Test
# Stage Name: common_csenv-for-test
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM csenv AS common_csenv-for-test

# Install & Setup LiteSpeed
ENV DEBIAN_FRONTEND noninteractive
RUN wget -q -O - http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash \
    && apt-get -q -y install --no-install-recommends \
         sudo \
         openlitespeed
COPY httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY vhconf.conf /usr/local/lsws/conf/vhosts/www/vhconf.conf

# Install Node.js (current)
RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash - \
    && apt-get -q -y install --no-install-recommends \
         nodejs

# Install Google Chrome
WORKDIR /tmp
RUN apt-get -q -y install --no-install-recommends \
      gnupg \
      fonts-ipafont \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get -q -y install --no-install-recommends ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# Clean up Apt Cache
RUN apt-get -q -y clean \
    && rm -rf /var/lib/apt/lists/*

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh



################################################################################
# CSEnv for Test
# Stage Name: csenv-for-test
################################################################################
FROM common_csenv-for-test AS csenv-for-test

# Configure User www-data to allow sudo
RUN echo 'www-data ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-www-data \
    && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# Move Perl location
RUN mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Switch User to www-data
WORKDIR /var/www
USER www-data

# Define default command (Start LiteSpeed Webserver and then watch logs.)
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/tail", "-F", "/usr/local/lsws/logs/error.log", "/usr/local/lsws/logs/access.log"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose LiteSpeed WebAdmin Port
EXPOSE 7080

# Expose LiteSpeed WebServer Port
EXPOSE 80



################################################################################
# CircleCI - CSEnv for Test
# Stage Name: circleci-csenv-for-test
################################################################################
FROM common_csenv-for-test AS circleci-csenv-for-test

# Setup for CircleCI
# - Add User circleci and config to allow sudo
# - Pre-Install packages and setup for CircleCI
# - Set Environment Variables for CircleCI
RUN useradd --uid=3434 --user-group --create-home circleci \
    && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
    && sudo -u circleci mkdir /home/circleci/project \
    && apt-get -q -y update \
    && apt-get -q -y install --no-install-recommends \
         git \
         ssh \
         tar \
         gzip \
         ca-certificates \
         nkf \
    && apt-get -q -y clean \
    && rm -rf /var/lib/apt/lists/*
ENV PATH=/home/circleci/bin:/home/circleci/.local/bin:$PATH

# Move Perl location
RUN mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Switch User to circleci
WORKDIR /home/circleci
USER circleci

# Define default command (Start LiteSpeed Webserver.)
ENTRYPOINT ["entrypoint.sh"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose LiteSpeed WebAdmin Port
EXPOSE 7080

# Expose LiteSpeed WebServer Port
EXPOSE 80
