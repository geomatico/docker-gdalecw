# Based on https://github.com/luipir/docker-gdalecw Thanks Luigi!
# References:
# GDAL compilations steps are inspired by  https://github.com/GeographicaGS/Docker-GDAL2
# ECW installation is inspired by: https://gist.github.com/klokan/bfd4a07e8072ffae4bb6
#
FROM debian:stable-slim
MAINTAINER Francisco P. Sampayo <francisco.perez@geomatico.es>

# Load assets overrided in docker-compose.yml
ENV ROOTDIR /usr/local/
ARG GDAL_VERSION=2.4.4
ARG ECW_INSTALLER=ERDASECWJP2SDKv54Update1forLinux
ARG ECW_UNZIPPED_INSTALLER=ERDAS_ECWJP2_SDK-5.4.0.bin
ARG ECW_INSTALLED_PATH=ERDAS-ECW_JPEG_2000_SDK-5.4.0

# Install and compile all on same docker layer to improve image size
# mkdir hack by https://stackoverflow.com/questions/61815233/install-java-runtime-in-debian-based-docker-image
RUN mkdir -p /usr/share/man/man1 /usr/share/man/man2 && \
    apt-get update -y && \
    apt-get install -y \
        wget \
        software-properties-common \
        build-essential \
#        python-dev \
#        python3-dev \
#        python-numpy \
#        python3-numpy \
        openjdk-11-jdk \
        swig \
        ant \
        libspatialite-dev \
        sqlite3 \
        libpq-dev \
        libcurl4-gnutls-dev \
        libproj-dev \
        libxml2-dev \
        libgeos-dev \
        libnetcdf-dev \
        libpoppler-dev \
        libspatialite-dev \
        libhdf4-alt-dev \
        libhdf5-serial-dev \
        bash-completion \
        cmake \
        unzip \
    # Download Gdal source
    && cd $ROOTDIR/src/ \
    && wget http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz \
    # Download Erdas ECW SDK
    && mkdir -p $ROOTDIR/ERDAS_ECW_SDK \
    && cd $ROOTDIR/ERDAS_ECW_SDK \
    && wget https://go.hexagongeospatial.com/${ECW_INSTALLER} \
    # Prepare ECW SDK accepting the lincese and installing:
    # Desktop_Read-Only (eg. choise 1)
    # command MORE=-v is useful to avoid to block installer reading the license.
    # see 'more' command documentation.
    # printf '1\nyes\n' is useful only to simulate user to select and accept license
    && unzip ${ECW_INSTALLER} \
    && printf '1\nyes\n' | MORE=-V bash ./${ECW_UNZIPPED_INSTALLER} \
    && mv /hexagon $ROOTDIR \
    && rm -fr $ROOTDIR/ERDAS_ECW_SDK \
    # configuring ECW SDK to allow gdal compilation
    && cp -r $ROOTDIR/hexagon/${ECW_INSTALLED_PATH}/Desktop_Read-Only/* $ROOTDIR/hexagon \
    && rm -fr $ROOTDIR/hexagon/${ECW_INSTALLED_PATH}/Desktop_Read-Only \
    && rm -r $ROOTDIR/hexagon/lib/x64 \
    && mv $ROOTDIR/hexagon/lib/newabi/x64 $ROOTDIR/hexagon/lib/x64 \
    && cp $ROOTDIR/hexagon/lib/x64/release/libNCSEcw* $ROOTDIR/lib \
    && ldconfig $ROOTDIR/hexagon \
    # Configure JAVA_HOME and GDAL_HOME
    && JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    && GDAL_HOME=$ROOTDIR \
    && ln -s $JAVA_HOME /usr/java \
    # Compile GDAL
    && cd $ROOTDIR/src \
    && tar -xvf gdal-${GDAL_VERSION}.tar.gz \
    && cd gdal-${GDAL_VERSION} \
    # && ./configure --with-python --with-java=$JAVA_HOME --with-spatialite --with-pg --with-curl --with-ecw=/usr/local/hexagon \
    && ./configure --with-java=$JAVA_HOME --with-spatialite --with-pg --with-curl --with-ecw=/usr/local/hexagon \
    && make -j $(nproc) \
    && make install && ldconfig \
    && apt-get update -y \
#    && cd $ROOTDIR \
#    && cd src/gdal-${GDAL_VERSION}/swig/python \
#    && python3 setup.py build \
#    && python3 setup.py install \
    && cd $ROOTDIR \
    && cd src/gdal-${GDAL_VERSION}/swig/java \
    && make \
    && make install && ldconfig \
    && apt-get remove -y --purge build-essential  python-dev python3-dev \
    && mkdir $ROOTDIR/java \
    && cp gdal.jar $ROOTDIR/java \
    && cd $ROOTDIR \
    && rm -Rf $ROOTDIR/src/gdal* \
    && rm -Rf $ROOTDIR/hexagon \
    && rm -Rf $ROOTDIR/lib/*.a \
    && rm -Rf $ROOTDIR/lib/*.debug \
    #Clean apt
    && apt-get remove -y --purge ant swig cmake wget build-essential \
           # python-dev python3-dev \
    && apt clean -y\
    && apt autoclean -y \
    && apt autoremove -y

# # Output version and capabilities by default.
CMD    gdalinfo --version \
    && gdalinfo --formats \
    && ogrinfo --formats
