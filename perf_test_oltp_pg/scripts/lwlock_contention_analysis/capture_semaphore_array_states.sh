#!/bin/bash

sudo ipcs -s | awk '/postgres/ {print $2}' | sudo -u postgres xargs -r -I SEMID ipcs -s -i SEMID
