FROM registry.opensuse.org/opensuse/tumbleweed:latest

COPY files/37composefs/ /usr/lib/dracut/modules.d/37composefs/

ENV DEV_DEPS="ostree-devel git cargo rust"
ENV DRACUT_NO_XATTR=1

RUN zypper install -y ${DEV_DEPS}

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    git clone https://github.com/bootc-dev/bootc.git /tmp/bootc && \
    cd /tmp/bootc && \
    make bin install-all install-initramfs-dracut

RUN zypper remove --clean-deps -y ${DEV_DEPS}

RUN zypper install -y \
  dracut \
  composefs \
  composefs-experimental \
  kernel-default \
  kernel-firmware-all \
  systemd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  udev \
  cpio \
  zstd \
  binutils \
  dosfstools \
  conmon \
  crun \
  netavark \
  skopeo \
  dbus-1 \
  dbus-1-daemon \
  dbus-broker \
  systemd-boot

RUN cp /usr/bin/bootc-initramfs-setup /usr/lib/dracut/modules.d/37composefs

RUN echo 'add_drivers+=" erofs "' >> /etc/dracut.conf.d/composefs.conf

RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

RUN sh -c 'export KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" && \
    dracut --force --add debug --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION"  "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img"'

RUN rm -rf /var /boot /home /root /usr/local /srv && \
    mkdir -p /var /boot /sysroot && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/srv /srv && \
    ln -s sysroot/ostree ostree && \
    ln -s /var/usrlocal /usr/local

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd"

# If you want a desktop :)
RUN zypper install -y -t pattern kde && zypper install -y konsole sddm-qt6 vim dolphin

# Necessary for `bootc install`
RUN mkdir -p /usr/lib/ostree && \
    printf  "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | \
    tee "/usr/lib/ostree/prepare-root.conf"

RUN bootc container lint
