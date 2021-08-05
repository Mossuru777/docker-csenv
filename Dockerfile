################################################################################
# Perl5.26.3 with ImageMagick6.9.10-86
# Stage Name: perl5.26.3-with-imagemagick6.9.10-86
################################################################################
FROM perl:5.26.3-buster AS perl5.26.3-with-imagemagick6.9.10-86
MAINTAINER Mossuru777 "mossuru777@gmail.com"

# Setup
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         sed \
         locales \
         tzdata \
    && sed -i -e 's/^# *\(ja_JP.UTF-8.*\)/\1/' /etc/locale.gen \
    && locale-gen
ENV TZ Asia/Tokyo

# Install ImageMagick & PerlMagick
RUN apt-get -q -y autoremove \
      imagemagick \
      imagemagick-6.q16 \
      imagemagick-6-common \
    && apt-get -y install --no-install-recommends \
         libgif7 \
         libgif-dev \
         libpng16-16 \
         libpng-dev \
    && curl -sSL https://github.com/ImageMagick/ImageMagick6/archive/refs/tags/6.9.10-86.tar.gz -o /tmp/imagemagick-6.9.10-86.tar.gz \
    && echo '82c585b4d1fa599a5fd510342c552c20e6b0edab4d837a62aaaed34b5b356890 /tmp/imagemagick-6.9.10-86.tar.gz' | sha256sum -c - \
    && mkdir -p /usr/src/imagemagick \
    && tar --strip-components=1 -xaf /tmp/imagemagick-6.9.10-86.tar.gz -C /usr/src/imagemagick \
    && cd /usr/src/imagemagick \
    && ./configure LDFLAGS="-L/usr/local/lib/perl5/5.26.3/x86_64-linux-gnu/CORE" --enable-shared --with-perl=/usr/local/bin/perl \
    && make -j$(nproc) \
    && make install \
    && cd /root \
    && rm -fr /usr/src/imagemagick /tmp/** \
    && ldconfig

# Clean up Apt Cache
RUN apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*



################################################################################
# CSEnv
# Stage Name: csenv
################################################################################
FROM perl5.26.3-with-imagemagick6.9.10-86 AS csenv

# Install CPAN modules
COPY cpanfile /tmp/
RUN cpanm --notest --installdeps /tmp \
    && rm -fr /root/.cpanm /tmp/**



################################################################################
# [Base Stage] CSEnv for Test
# Stage Name: base_csenv-for-test
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM csenv AS base_csenv-for-test

# Create /var/www/html
RUN mkdir -p /var/www/html

# Install common packages
RUN apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         sudo

# Install Node.js (current)
RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash - \
    && apt-get -q -y install --no-install-recommends \
         nodejs

# Install Google Chrome
RUN apt-get -q -y install --no-install-recommends \
      gnupg \
      fonts-ipafont \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get -q -y install --no-install-recommends /tmp/google-chrome-stable_current_amd64.deb \
    && rm /tmp/google-chrome-stable_current_amd64.deb \
    && sed -i -e 's/"\$HERE\/chrome" "\$@"/"$HERE\/chrome" "--disable-gpu" "$@"/' /opt/google/chrome/google-chrome

# Clean up Apt Cache
RUN apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*



################################################################################
# [Base Stage] CSEnv for Test with LiteSpeed
# Stage Name: base_csenv-for-test-litespeed
#
# *** DO NOT PUBLISH AS A DOCKER IMAGE ***
#
################################################################################
FROM base_csenv-for-test AS base_csenv-for-test-litespeed

# Install & Setup LiteSpeed
ENV DEBIAN_FRONTEND noninteractive
RUN wget -q -O - http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash \
    && apt-get -q -y install --no-install-recommends \
         openlitespeed \
#--- workaround for "[STDERR] PHP Notice:  Undefined index: LS_AI_MIME_TYPE in /usr/local/lsws/share/autoindex/default.php on line 299"
    && cp -a /usr/local/lsws/share/autoindex/default.php /usr/local/lsws/share/autoindex/default.php.orig \
    && sed -i -e "s@^\(\$mime_type = \$_SERVER\['LS_AI_MIME_TYPE'\]\);@\\1 ?? null;@" /usr/local/lsws/share/autoindex/default.php \
#-------------------------------------------------------------------------------
    && mv /usr/local/lsws/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.orig
COPY litespeed/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY litespeed/vhconf.conf /usr/local/lsws/conf/vhosts/www/vhconf.conf

# Clean up Apt Cache
RUN apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Add a script to be executed every time the container starts.
COPY litespeed/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh



################################################################################
# CSEnv for Test with LiteSpeed for General
# Stage Name: csenv-for-test-litespeed-general
################################################################################
FROM base_csenv-for-test-litespeed AS csenv-for-test-litespeed-general

# Configure User www-data to allow sudo
RUN echo 'www-data ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-www-data \
    && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# Move Perl location
RUN mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Switch User to www-data
WORKDIR /var/www
USER www-data

# Define default command (Start LiteSpeed Webserver and then watch error logs.)
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/tail", "-F", "/usr/local/lsws/logs/stderr.log", "/usr/local/lsws/logs/error.log"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose LiteSpeed WebAdmin Port
EXPOSE 7080

# Expose LiteSpeed WebServer Port
EXPOSE 80



################################################################################
# CSEnv for Test with LiteSpeed for CircleCI
# Stage Name: csenv-for-test-litespeed-circleci
################################################################################
FROM base_csenv-for-test-litespeed AS csenv-for-test-litespeed-circleci

# Setup for CircleCI
# - Add User circleci and config to allow sudo
# - Pre-Install packages and setup for CircleCI
# - Set Environment Variables for CircleCI
RUN useradd --uid=3434 --user-group --create-home circleci \
    && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
    && sudo -u circleci mkdir /home/circleci/project \
    && apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         git \
         ssh \
         tar \
         gzip \
         ca-certificates \
         nkf \
    && apt-get -q clean \
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

# Expose LiteSpeed WebServer Port
EXPOSE 80



################################################################################
# CSEnv for Test with Apache for General
# Stage Name: csenv-for-test-apache-general
################################################################################
FROM base_csenv-for-test AS csenv-for-test-apache-general

# Install & Setup Apache
RUN apt-get -q update \
    && apt-get -q -y install --no-install-recommends \
         apache2

# Enable site configuration
COPY apache/all-catch.conf /etc/apache2/sites-available/all-catch.conf
RUN a2enmod cgi \
    && a2dissite 000-default \
    && a2ensite all-catch \
    && service apache2 stop

# Configure User www-data to allow sudo
RUN echo 'www-data ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-www-data \
    && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# Move Perl location
RUN mv /usr/bin/perl /usr/bin/perl.orig \
    && ln -s /usr/local/bin/perl /usr/bin/perl

# Add a script to be executed every time the container starts.
COPY apache/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

# Switch User to www-data
WORKDIR /var/www
USER www-data

# Define default command (Start Apache Webserver and then watch error logs.)
ENTRYPOINT ["entrypoint.sh"]
CMD ["sudo", "/usr/bin/tail", "-F", "/var/log/apache2/error.log"]

# Define mountable directories
VOLUME ["/var/www/html"]

# Expose Apache WebServer Port
EXPOSE 80
