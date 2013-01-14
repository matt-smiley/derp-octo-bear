#!/bin/bash

sudo ipcs -s | awk '/postgres/ {print $2}' | sudo xargs -r -I SEMID ipcs -s -i SEMID
