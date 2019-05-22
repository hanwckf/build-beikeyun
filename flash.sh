#!/bin/sh

[ -z "$1" ] && echo "please specify img" && exit 1
[ ! -f "$1" ]  && echo "img not found!" && exit 1

rkdeveloptool db loader/rk3328_loader_v1.14.249.bin && \
 sleep 1 && rkdeveloptool wl 0x0 $1 && \
 sleep 1 && rkdeveloptool rd
