#! /bin/bash

DST_IMAGE_REPO=""

cat images.txt | while read line
do
        while :
        do
                skopeo sync --src=docker --dest=docker $line $DST_IMAGE_REPO
                if [ "$?" == "0" ]; then
                        break
                fi
        done
done