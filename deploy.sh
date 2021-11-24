#!/bin/bash
export HCLOUD_TOKEN=v7PmTeBj1atesVQLLVZcUSunsCTibWKcx0J33A2b1hesuWNavMrRSRuREJOPejDT
export HCLOUD_CONTEXT=PZC

NETWORK_NAME=rd-test

hcloud network create --ip-range 10.10.10.0/24 --name $NETWORK_NAME
 
